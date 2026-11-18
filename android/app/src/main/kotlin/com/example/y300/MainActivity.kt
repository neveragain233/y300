package com.example.y300

import android.Manifest
import android.content.ContentValues
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.lang.reflect.Method
import java.lang.reflect.Modifier

class MainActivity : FlutterActivity() {
    private companion object {
        const val EXPORT_CHANNEL = "com.adws.y300/reader_image_export"
        const val DEVICE_MEMORY_CHANNEL = "com.adws.y300/device_memory"
        const val EPDC_CHANNEL = "com.adws.y300/epdc"
        const val EINK_KEYS_CHANNEL = "com.adws.y300/eink_keys"
        const val STORAGE_PERMISSION_REQUEST = 7301

        // 掌阅 SmartOS 的 EPDC 翻页模式；方向码按屏幕旋转各取一档。
        private const val EPDC_FORCE_MODE_PAGE_TURN = 0x01000063
        private val EPDC_FORWARD_DIRECTIONS = intArrayOf(1, 3, 2, 4)
        private val EPDC_BACKWARD_DIRECTIONS = intArrayOf(2, 4, 1, 3)

        @Volatile
        private var epdcProbed = false

        @Volatile
        private var epdcAvailable = false
        private var epdcPostMethod: Method? = null
        private var epdcForceMethod: Method? = null
        private var epdcTarget: Any? = null
    }

    private var pendingPermissionExport: PendingExport? = null
    private var einkKeysChannel: MethodChannel? = null

    // 仅在阅读器前台且用户开启时拦截音量键/翻页键。
    @Volatile
    private var volumePagingEnabled: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPORT_CHANNEL)
            .setMethodCallHandler(::handleExportCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_MEMORY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "getProfile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                result.success(
                    mapOf(
                        "memoryClassMb" to manager.memoryClass,
                        "isLowRamDevice" to manager.isLowRamDevice,
                    ),
                )
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EPDC_CHANNEL)
            .setMethodCallHandler(::handleEpdcCall)
        val keysChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EINK_KEYS_CHANNEL,
        )
        keysChannel.setMethodCallHandler { call, result ->
            if (call.method == "setVolumePagingEnabled") {
                volumePagingEnabled = call.arguments as? Boolean ?: false
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        einkKeysChannel = keysChannel
    }

    /**
     * 阅读器开启硬件键翻页时，把音量键与翻页键转成翻页方向；只处理首次按下，
     * 长按重复交给阅读器自己决定，不在这里连续翻页。
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumePagingEnabled) {
            val direction = when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_PAGE_UP -> "up"
                KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_PAGE_DOWN -> "down"
                else -> null
            }
            if (direction != null) {
                if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                    einkKeysChannel?.invokeMethod("onHardwarePageKey", direction)
                }
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun handleEpdcCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "triggerPageRipple") {
            result.notImplemented()
            return
        }
        val forward = call.argument<Boolean>("forward") ?: true
        val speed = call.argument<String>("speed")
        result.success(triggerIreaderPageRipple(forward = forward, speed = speed))
    }

    /**
     * 反射调用掌阅 SmartOS 的 `android.eink.EPDCDevice`，为下一次屏幕提交挂上
     * 翻页水波纹。非掌阅设备首次探测失败后缓存结果，后续调用零开销。
     */
    private fun triggerIreaderPageRipple(forward: Boolean, speed: String?): Boolean {
        return try {
            ensureEpdcProbed()
            if (!epdcAvailable) {
                return false
            }
            val postMethod = epdcPostMethod ?: return false
            val target = if (Modifier.isStatic(postMethod.modifiers)) null else epdcTarget
            val rotation = currentDisplayRotation().coerceIn(0, 3)
            val directionCode = if (forward) {
                EPDC_FORWARD_DIRECTIONS[rotation]
            } else {
                EPDC_BACKWARD_DIRECTIONS[rotation]
            }
            val speedBit = when (speed?.lowercase()) {
                "slow" -> 128
                "fast" -> 0
                else -> 64
            }
            postMethod.invoke(target, "next-effect-type ${directionCode or speedBit}")
            epdcForceMethod?.let { forceMethod ->
                val forceTarget = if (Modifier.isStatic(forceMethod.modifiers)) {
                    null
                } else {
                    epdcTarget
                }
                forceMethod.invoke(forceTarget, EPDC_FORCE_MODE_PAGE_TURN)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun currentDisplayRotation(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display?.rotation ?: Surface.ROTATION_0
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.rotation
            }
        } catch (_: Throwable) {
            Surface.ROTATION_0
        }
    }

    private fun ensureEpdcProbed() {
        if (epdcProbed) return
        synchronized(MainActivity::class.java) {
            if (epdcProbed) return
            try {
                val epdcClass = Class.forName("android.eink.EPDCDevice")
                val allMethods = (epdcClass.methods.toList() + epdcClass.declaredMethods.toList())
                    .distinctBy { method ->
                        "${method.name}:${method.parameterTypes.joinToString(",") { it.name }}"
                    }

                val postMethod =
                    findExactMethod(epdcClass, "nativePostCommand", String::class.java)
                        ?: allMethods.firstOrNull { method ->
                            Modifier.isStatic(method.modifiers) &&
                                method.parameterTypes.size == 1 &&
                                method.parameterTypes[0] == String::class.java &&
                                isPostMethodName(method.name)
                        }
                        ?: allMethods.firstOrNull { method ->
                            method.parameterTypes.size == 1 &&
                                method.parameterTypes[0] == String::class.java &&
                                isPostMethodName(method.name)
                        }

                val forceMethod =
                    findExactMethod(epdcClass, "setForceNextPostMode", Int::class.javaPrimitiveType!!)
                        ?: allMethods.firstOrNull { method ->
                            Modifier.isStatic(method.modifiers) &&
                                method.parameterTypes.size == 1 &&
                                method.parameterTypes[0] == Int::class.javaPrimitiveType &&
                                method.name.lowercase().contains("force")
                        }
                        ?: allMethods.firstOrNull { method ->
                            method.parameterTypes.size == 1 &&
                                method.parameterTypes[0] == Int::class.javaPrimitiveType &&
                                method.name.lowercase().contains("force")
                        }

                var target: Any? = null
                if ((postMethod != null && !Modifier.isStatic(postMethod.modifiers)) ||
                    (forceMethod != null && !Modifier.isStatic(forceMethod.modifiers))
                ) {
                    target = resolveEpdcSingleton(epdcClass, allMethods)
                }

                postMethod?.isAccessible = true
                forceMethod?.isAccessible = true
                epdcPostMethod = postMethod
                epdcForceMethod = forceMethod
                epdcTarget = target
                epdcAvailable = postMethod != null &&
                    (Modifier.isStatic(postMethod.modifiers) || target != null)
            } catch (_: Throwable) {
                epdcAvailable = false
                epdcPostMethod = null
                epdcForceMethod = null
                epdcTarget = null
            } finally {
                epdcProbed = true
            }
        }
    }

    private fun findExactMethod(
        clazz: Class<*>,
        name: String,
        vararg paramTypes: Class<*>,
    ): Method? {
        return try {
            clazz.getMethod(name, *paramTypes)
        } catch (_: Throwable) {
            try {
                clazz.getDeclaredMethod(name, *paramTypes)
            } catch (_: Throwable) {
                null
            }
        }
    }

    private fun isPostMethodName(name: String): Boolean {
        val lower = name.lowercase()
        return lower.contains("postcommand") || lower.contains("post")
    }

    private fun resolveEpdcSingleton(epdcClass: Class<*>, methods: List<Method>): Any? {
        val getter = methods.firstOrNull { method ->
            Modifier.isStatic(method.modifiers) &&
                method.parameterTypes.isEmpty() &&
                epdcClass.isAssignableFrom(method.returnType)
        }
        if (getter != null) {
            return try {
                getter.isAccessible = true
                getter.invoke(null)
            } catch (_: Throwable) {
                null
            }
        }
        return try {
            val constructor = epdcClass.getDeclaredConstructor()
            constructor.isAccessible = true
            constructor.newInstance()
        } catch (_: Throwable) {
            null
        }
    }

    private fun handleExportCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveImage") {
            result.notImplemented()
            return
        }
        val sourcePath = call.argument<String>("sourcePath")?.trim().orEmpty()
        val displayName = call.argument<String>("displayName")?.trim().orEmpty()
        val mimeType = call.argument<String>("mimeType")?.trim().orEmpty()
        val albumName = call.argument<String>("albumName")?.trim().orEmpty().ifEmpty { "Y300" }
        if (sourcePath.isEmpty() || displayName.isEmpty() || mimeType.isEmpty()) {
            result.error("mediaWriteFailed", "Invalid image export request", null)
            return
        }
        val request = PendingExport(sourcePath, displayName, mimeType, albumName, result)
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.M..Build.VERSION_CODES.P &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingPermissionExport != null) {
                result.error("mediaWriteFailed", "Another permission request is active", null)
                return
            }
            pendingPermissionExport = request
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST,
            )
            return
        }
        saveImage(request)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_PERMISSION_REQUEST) return
        val request = pendingPermissionExport ?: return
        pendingPermissionExport = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveImage(request)
        } else {
            request.result.error("permissionDenied", "Storage permission was denied", null)
        }
    }

    private fun saveImage(request: PendingExport) {
        val source = File(request.sourcePath)
        if (!source.isFile) {
            request.result.error("mediaWriteFailed", "Cached image file is missing", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveToMediaStore(request, source)
            } else {
                saveToLegacyPictures(request, source)
            }
        } catch (error: Exception) {
            request.result.error("mediaWriteFailed", error.message, null)
        }
    }

    private fun saveToMediaStore(request: PendingExport, source: File) {
        val resolver = contentResolver
        val relativePath = "${Environment.DIRECTORY_PICTURES}/${request.albumName}"
        val displayName = uniqueMediaStoreName(request.displayName, relativePath)
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, request.mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Unable to create MediaStore entry")
        try {
            resolver.openOutputStream(uri, "w")?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Unable to open MediaStore output")
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) },
                null,
                null,
            )
            request.result.success(
                mapOf(
                    "locator" to uri.toString(),
                    "displayLocation" to "$relativePath/$displayName",
                ),
            )
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun uniqueMediaStoreName(displayName: String, relativePath: String): String {
        val dot = displayName.lastIndexOf('.')
        val base = if (dot > 0) displayName.substring(0, dot) else displayName
        val extension = if (dot > 0) displayName.substring(dot) else ""
        var candidate = displayName
        var suffix = 1
        while (mediaStoreNameExists(candidate, relativePath)) {
            candidate = "$base ($suffix)$extension"
            suffix += 1
        }
        return candidate
    }

    private fun mediaStoreNameExists(displayName: String, relativePath: String): Boolean {
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val selection =
            "${MediaStore.Images.Media.DISPLAY_NAME}=? AND ${MediaStore.Images.Media.RELATIVE_PATH}=?"
        val normalizedPath = if (relativePath.endsWith('/')) relativePath else "$relativePath/"
        return contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            arrayOf(displayName, normalizedPath),
            null,
        )?.use { it.moveToFirst() } == true
    }

    @Suppress("DEPRECATION")
    private fun saveToLegacyPictures(request: PendingExport, source: File) {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            request.albumName,
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Unable to create Pictures directory")
        }
        val destination = uniqueLegacyFile(directory, request.displayName)
        FileInputStream(source).use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(destination.absolutePath),
            arrayOf(request.mimeType),
        ) { _, uri ->
            request.result.success(
                mapOf(
                    "locator" to (uri ?: Uri.fromFile(destination)).toString(),
                    "displayLocation" to "Pictures/${request.albumName}/${destination.name}",
                ),
            )
        }
    }

    private fun uniqueLegacyFile(directory: File, displayName: String): File {
        val dot = displayName.lastIndexOf('.')
        val base = if (dot > 0) displayName.substring(0, dot) else displayName
        val extension = if (dot > 0) displayName.substring(dot) else ""
        var candidate = File(directory, displayName)
        var suffix = 1
        while (candidate.exists()) {
            candidate = File(directory, "$base ($suffix)$extension")
            suffix += 1
        }
        return candidate
    }

    private data class PendingExport(
        val sourcePath: String,
        val displayName: String,
        val mimeType: String,
        val albumName: String,
        val result: MethodChannel.Result,
    )
}

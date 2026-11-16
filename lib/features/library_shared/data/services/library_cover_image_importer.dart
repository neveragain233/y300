import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:y300/features/library_shared/data/services/library_cover_store.dart';

/// 把帖子候选图片取到本地临时文件，交给既有自定义封面链安装。
///
/// 下载沿用封面专用传输（Cookie、表单令牌、受保护资源与重放都由
/// [LibraryCoverDownloader] 背后的共享实现处理），不重建请求通道。
class LibraryCoverImageImporter {
  LibraryCoverImageImporter({
    required LibraryCoverDownloader downloader,
    required Future<String> rootPath,
  }) : _downloader = downloader,
       _rootPath = rootPath;

  final LibraryCoverDownloader _downloader;
  final Future<String> _rootPath;

  Future<String> import({required String imageUrl}) async {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      throw ArgumentError.value(imageUrl, 'imageUrl');
    }
    final root = io.Directory(await _rootPath);
    await root.create(recursive: true);
    final digest = sha256.convert(utf8.encode(url)).toString();
    final target = io.File(p.join(root.path, '$digest.img'));
    final temporary = io.File('${target.path}.part');
    if (await temporary.exists()) {
      await temporary.delete();
    }
    try {
      await _downloader.download(url: url, targetPath: temporary.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
    return target.path;
  }
}

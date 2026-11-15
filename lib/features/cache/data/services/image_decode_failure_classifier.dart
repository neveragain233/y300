import 'dart:async';
import 'dart:io' as io;

/// Whether a local decode failure proves the cached bytes themselves are bad.
///
/// Only corrupted content can be repaired by downloading the resource again.
/// Allocation failures (an oversized bitmap in a constrained process) and
/// filesystem errors say nothing about the cached bytes, so their files must
/// survive an explicit retry instead of being deleted.
///
/// This build of Flutter surfaces codec errors as plain [Exception]s carrying
/// the engine message rather than a dedicated codec exception type. The type
/// name check keeps newer Flutter versions classified without a hard import.
bool isCorruptedImageDecodeFailure(Object error) {
  if (error is io.FileSystemException || error is OutOfMemoryError) {
    return false;
  }
  if (error is TimeoutException) {
    return false;
  }
  final typeName = error.runtimeType.toString();
  if (typeName == 'ImageCodecException' ||
      typeName == 'ImageDecoderException') {
    return true;
  }
  if (error is! Exception) {
    return false;
  }
  final message = error.toString().toLowerCase();
  if (message.contains('out of memory') ||
      message.contains('outofmemory') ||
      message.contains('allocation failed')) {
    return false;
  }
  return true;
}

import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:y300/features/library_shared/data/services/library_cover_image_importer.dart';
import 'package:y300/features/library_shared/data/services/library_cover_store.dart';

void main() {
  late io.Directory root;

  setUp(() async {
    root = await io.Directory.systemTemp.createTemp('cover-import-test');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('downloads candidate images to deterministic temporary files', () async {
    final downloader = _FakeDownloader();
    final importer = LibraryCoverImageImporter(
      downloader: downloader,
      rootPath: Future<String>.value(root.path),
    );

    final path = await importer.import(
      imageUrl: ' https://bbs.yamibo.com/forum/a.jpg ',
    );

    expect(downloader.urls, <String>['https://bbs.yamibo.com/forum/a.jpg']);
    expect(p.basename(path).endsWith('.img'), isTrue);
    expect(await io.File(path).readAsBytes(), _FakeDownloader.bytes);

    final again = await importer.import(
      imageUrl: 'https://bbs.yamibo.com/forum/a.jpg',
    );
    expect(again, path);
    expect(downloader.urls, hasLength(2));
  });

  test('propagates download failures and removes the partial file', () async {
    final downloader = _FailingDownloader();
    final importer = LibraryCoverImageImporter(
      downloader: downloader,
      rootPath: Future<String>.value(root.path),
    );

    await expectLater(
      importer.import(imageUrl: 'https://bbs.yamibo.com/forum/a.jpg'),
      throwsStateError,
    );
    final leftovers = await root
        .list(recursive: true)
        .where((entry) => entry is io.File)
        .toList();
    expect(leftovers, isEmpty);
  });
}

class _FakeDownloader implements LibraryCoverDownloader {
  static final List<int> bytes = utf8.encode('cover-bytes');
  final List<String> urls = <String>[];

  @override
  Future<void> download({
    required String url,
    required String targetPath,
  }) async {
    urls.add(url);
    await io.File(targetPath).writeAsBytes(bytes, flush: true);
  }
}

class _FailingDownloader implements LibraryCoverDownloader {
  @override
  Future<void> download({
    required String url,
    required String targetPath,
  }) async {
    await io.File(targetPath).writeAsBytes(const <int>[1, 2, 3], flush: true);
    throw StateError('download failed');
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/features/storage/data/storage_location_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('custom download root uses the stable key and trims values', () async {
    final repository = StorageLocationRepositoryImpl();

    expect(await repository.getCustomStorageRoot(), isNull);

    await repository.setCustomStorageRoot('  E:/Y300  ');
    expect(await repository.getCustomStorageRoot(), 'E:/Y300');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('download_storage_dir'), 'E:/Y300');

    await repository.setCustomStorageRoot('   ');
    expect(await repository.getCustomStorageRoot(), isNull);
    expect(prefs.containsKey('download_storage_dir'), isFalse);
  });

  group('androidMediaRootFor', () {
    test('derives the shared media root beside the app files dir', () {
      expect(
        androidMediaRootFor(
          '/storage/emulated/0/Android/data/com.adws.y300.fork/files',
        ),
        '/storage/emulated/0/Android/media/com.adws.y300.fork/Y300',
      );
    });

    test('stays on the storage volume that hosts the app files dir', () {
      expect(
        androidMediaRootFor(
          '/storage/1A2B-3C4D/Android/data/com.adws.y300.personal/files',
        ),
        '/storage/1A2B-3C4D/Android/media/com.adws.y300.personal/Y300',
      );
    });

    test('returns null for missing or unexpected layouts', () {
      expect(androidMediaRootFor(null), isNull);
      expect(androidMediaRootFor('  '), isNull);
      expect(androidMediaRootFor('/data/user/0/com.adws.y300/files'), isNull);
      expect(
        androidMediaRootFor('/storage/emulated/0/Android/other/pkg/files'),
        isNull,
      );
    });
  });
}

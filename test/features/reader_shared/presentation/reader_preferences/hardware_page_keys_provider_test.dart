import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/hardware_page_keys_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hardware page keys default off and persist the toggle', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(hardwarePageKeysEnabledProvider.future), isFalse);

    await container
        .read(hardwarePageKeysEnabledProvider.notifier)
        .setEnabled(true);

    expect(container.read(hardwarePageKeysEnabledProvider).value, isTrue);
    final stored = await container
        .read(preferencesStoreProvider)
        .read(PreferenceKeys.readerHardwarePageKeys);
    expect(stored, isTrue);
  });
}

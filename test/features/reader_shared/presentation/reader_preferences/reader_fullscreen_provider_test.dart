import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/reader_fullscreen_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('immersive fullscreen defaults on and persists the toggle', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(readerFullscreenEnabledProvider.future),
      isTrue,
    );

    await container
        .read(readerFullscreenEnabledProvider.notifier)
        .setEnabled(false);

    expect(container.read(readerFullscreenEnabledProvider).value, isFalse);
    final stored = await container
        .read(preferencesStoreProvider)
        .read(PreferenceKeys.readerImmersiveFullscreen);
    expect(stored, isFalse);
  });
}

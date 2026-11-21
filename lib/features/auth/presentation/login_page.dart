import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/auth/presentation/auth_text_resolver.dart';
import 'package:y300/features/auth/presentation/login_controller.dart';
import 'package:y300/features/auth/presentation/login_state.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);
    final state = asyncState.value ?? LoginPageState.initial();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppPageAppBar(title: l10n.authLoginTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppTextInput(
            key: const Key('login-username-field'),
            label: l10n.authUsername,
            hintText: l10n.authUsernameHint,
            textInputAction: TextInputAction.next,
            onChanged: controller.updateUsername,
          ),
          const SizedBox(height: 12),
          AppTextInput(
            key: const Key('login-password-field'),
            label: l10n.authPassword,
            obscureText: true,
            onChanged: controller.updatePassword,
          ),
          const SizedBox(height: 14),
          FilledButton(
            key: const Key('login-submit-button'),
            onPressed: state.isSubmitting
                ? null
                : () async {
                    final session = await controller.submit();
                    if (session != null && context.mounted) {
                      ref
                          .read(authSessionControllerProvider.notifier)
                          .acceptSession(session);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.authLoginSuccess)),
                      );
                      Navigator.of(context).pop(true);
                    }
                  },
            child: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.authLoginTitle),
          ),
          if (state.failure != null) ...[
            const SizedBox(height: 12),
            Text(
              AuthTextResolver.loginFailure(l10n, state.failure!),
              key: const Key('login-error-text'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

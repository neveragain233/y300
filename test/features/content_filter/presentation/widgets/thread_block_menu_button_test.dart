import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' as riverpod_misc;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';
import 'package:y300/features/content_filter/presentation/widgets/thread_block_menu_button.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('blocks the list card author through the shared command', (
    tester,
  ) async {
    final submissions = <ForumBlacklistAddSubmission>[];
    await tester.pumpWidget(
      _app(
        sessionUid: '11',
        overrides: [
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '11',
            revision: 0,
          )),
          blacklistedUserIdsProvider.overrideWithValue(const <String>{}),
          blacklistAddSupportedProvider.overrideWithValue(true),
          blacklistRemoteLoaderProvider.overrideWithValue(
            (_) async => DataReadSuccess(
              data: const ForumBlacklistData(
                entries: <ForumBlacklistEntry>[],
                pagesRead: 1,
              ),
              capabilities: ForumBlacklistReadCapabilities(
                values: DataCapabilitySet.supported(
                  ForumBlacklistCapability.values,
                ),
              ),
              metadata: const DataReadMetadata.network(),
            ),
          ),
          blacklistAddCommandProvider.overrideWithValue((submission) async {
            submissions.add(submission);
            return DataCommandApplied(
              ForumBlacklistAddReceipt(
                userId: submission.userId,
                username: submission.username,
              ),
            );
          }),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('thread-block-menu-100')));
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('thread-block-author-action-100'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(submissions.single.userId, '42');
    expect(submissions.single.username, 'alice');
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadBlockMenuButton)),
    );
    expect(find.text(l10n.blacklistBlockApplied('alice')), findsOneWidget);
  });

  testWidgets('an inconclusive command keeps state and offers a list check', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        sessionUid: '11',
        overrides: [
          verifiedSessionOwnerProvider.overrideWithValue((
            uid: '11',
            revision: 0,
          )),
          blacklistedUserIdsProvider.overrideWithValue(const <String>{}),
          blacklistAddSupportedProvider.overrideWithValue(true),
          blacklistRemoteLoaderProvider.overrideWithValue(
            (_) async => DataReadSuccess(
              data: const ForumBlacklistData(
                entries: <ForumBlacklistEntry>[],
                pagesRead: 1,
              ),
              capabilities: ForumBlacklistReadCapabilities(
                values: DataCapabilitySet.supported(
                  ForumBlacklistCapability.values,
                ),
              ),
              metadata: const DataReadMetadata.network(),
            ),
          ),
          blacklistAddCommandProvider.overrideWithValue(
            (_) async => const DataCommandOutcomeUnknown(
              DataCommandFailure(
                kind: DataCommandFailureKind.unknown,
                retryPolicy: DataCommandRetryPolicy.never,
                diagnosticMessage: 'fixture',
              ),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('thread-block-menu-100')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thread-block-author-action-100')));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadBlockMenuButton)),
    );
    expect(find.text(l10n.blacklistBlockUnknown), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(l10n.blacklistReviewList),
        matching: find.byType(SnackBarAction),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.blacklistReviewList));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('content-filter-menu')), findsOneWidget);
  });

  testWidgets('hides the author action without a usable entry state', (
    tester,
  ) async {
    Future<void> expectHidden({
      required String? sessionUid,
      required Set<String> listed,
      String? authorId = '42',
      String? author = 'alice',
    }) async {
      await tester.pumpWidget(
        _app(
          sessionUid: sessionUid,
          authorId: authorId,
          author: author,
          overrides: [
            blacklistedUserIdsProvider.overrideWithValue(listed),
            blacklistAddSupportedProvider.overrideWithValue(true),
            blacklistRemoteLoaderProvider.overrideWithValue(
              (_) async => DataReadSuccess(
                data: const ForumBlacklistData(
                  entries: <ForumBlacklistEntry>[],
                  pagesRead: 1,
                ),
                capabilities: ForumBlacklistReadCapabilities(
                  values: DataCapabilitySet.supported(
                    ForumBlacklistCapability.values,
                  ),
                ),
                metadata: const DataReadMetadata.network(),
              ),
            ),
            blacklistAddCommandProvider.overrideWithValue(
              (_) async => throw StateError('must not submit'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thread-block-menu-100')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread-block-author-action-100')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('thread-block-action-100')));
      await tester.pumpAndSettle();
    }

    await expectHidden(sessionUid: null, listed: const <String>{});
    await expectHidden(sessionUid: '11', listed: const <String>{'42'});
    await expectHidden(
      sessionUid: '11',
      listed: const <String>{},
      authorId: '',
    );
    await expectHidden(sessionUid: '11', listed: const <String>{}, author: '');
    await expectHidden(sessionUid: '42', listed: const <String>{});
  });
}

Widget _app({
  required List<riverpod_misc.Override> overrides,
  String? sessionUid,
  String? authorId = '42',
  String? author = 'alice',
}) {
  final sessionStore = YamiboSessionStore();
  if (sessionUid != null) {
    sessionStore.saveExtracted(
      YamiboSessionSnapshot(
        isLoggedIn: true,
        uid: sessionUid,
        username: 'Reader',
        formhash: '',
        updatedAt: DateTime(2026, 1, 1),
        source: 'test',
      ),
    );
  }
  return ProviderScope(
    overrides: [
      yamiboSessionStoreProvider.overrideWithValue(sessionStore),
      ...overrides,
    ],
    child: LocalizedTestApp(
      home: Scaffold(
        body: Center(
          child: ThreadBlockMenuButton(
            tid: '100',
            subject: '测试主题',
            authorId: authorId,
            author: author,
          ),
        ),
      ),
    ),
  );
}

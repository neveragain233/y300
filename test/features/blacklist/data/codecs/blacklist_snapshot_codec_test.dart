import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/blacklist/data/codecs/blacklist_snapshot_codec.dart';
import 'package:y300/features/blacklist/domain/models/blacklist_snapshot.dart';

void main() {
  group('BlacklistSnapshotCodec', () {
    test('round-trips accounts without merging them', () {
      final snapshot = BlacklistSnapshot(
        accounts: <String, BlacklistAccountSnapshot>{
          '11': BlacklistAccountSnapshot(
            ownerUid: '11',
            members: const <BlacklistMember>[
              BlacklistMember(
                userId: '21',
                username: 'Alice',
                avatarUrl: 'https://example.test/avatar.jpg',
              ),
            ],
            lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
          '12': BlacklistAccountSnapshot(
            ownerUid: '12',
            members: const <BlacklistMember>[],
            lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        },
      );

      final decoded = BlacklistSnapshotCodec.decode(
        BlacklistSnapshotCodec.encode(snapshot),
      );

      expect(decoded.accountFor('11')!.members.single.username, 'Alice');
      expect(decoded.accountFor('12')!.members, isEmpty);
      expect(decoded.accountFor('13'), isNull);
    });

    test('tolerates damaged snapshots and invalid members', () {
      expect(BlacklistSnapshotCodec.decode(null).accounts, isEmpty);
      expect(BlacklistSnapshotCodec.decode('bad json').accounts, isEmpty);
      expect(
        BlacklistSnapshotCodec.decode(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'accounts': <String, Object?>{
              '11': <String, Object?>{
                'lastSuccessAt': 1000,
                'members': <Object?>[
                  <String, Object?>{'userId': '21', 'username': 'Alice'},
                  <String, Object?>{'userId': '', 'username': 'Bad'},
                  <String, Object?>{'userId': '22', 'username': ''},
                  <String, Object?>{'userId': '21', 'username': 'Alice again'},
                  'not-a-map',
                ],
              },
              'bad-uid': <String, Object?>{
                'lastSuccessAt': 1000,
                'members': <Object?>[],
              },
            },
          }),
        ).accounts.keys,
        <String>['11'],
      );
    });

    test('bounds retained accounts by most recent success', () {
      var snapshot = BlacklistSnapshot.empty;
      for (var index = 1; index <= 12; index += 1) {
        snapshot = snapshot.withAccount(
          BlacklistAccountSnapshot(
            ownerUid: '$index',
            members: const <BlacklistMember>[],
            lastSuccessAt: DateTime.fromMillisecondsSinceEpoch(index * 1000),
          ),
          maxAccounts: 10,
        );
      }

      expect(snapshot.accounts, hasLength(10));
      expect(snapshot.accountFor('1'), isNull);
      expect(snapshot.accountFor('12'), isNotNull);
    });
  });
}

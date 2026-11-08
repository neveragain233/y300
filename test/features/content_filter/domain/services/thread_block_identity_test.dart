import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/domain/services/thread_block_identity.dart';

void main() {
  group('ThreadBlockIdentity', () {
    test('canonicalizes positive numeric ids', () {
      expect(ThreadBlockIdentity.normalizeTid(' 000123 '), '123');
      expect(ThreadBlockIdentity.normalizeTid('123'), '123');
    });

    test('keeps non-numeric fixture ids as trimmed text', () {
      expect(
        ThreadBlockIdentity.normalizeTid(' preview-thread '),
        'preview-thread',
      );
    });

    test('rejects empty and non-positive values', () {
      expect(ThreadBlockIdentity.normalizeTid(null), isNull);
      expect(ThreadBlockIdentity.normalizeTid(''), isNull);
      expect(ThreadBlockIdentity.normalizeTid('0'), isNull);
      expect(ThreadBlockIdentity.normalizeTid('-1'), isNull);
      expect(ThreadBlockIdentity.matches('000123', '123'), isTrue);
      expect(ThreadBlockIdentity.matches('124', '123'), isFalse);
    });
  });
}

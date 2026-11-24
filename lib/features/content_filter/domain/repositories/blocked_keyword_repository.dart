import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';

abstract interface class BlockedKeywordRepository {
  Future<List<BlockedKeyword>> load();

  Future<void> save(List<BlockedKeyword> keywords);
}

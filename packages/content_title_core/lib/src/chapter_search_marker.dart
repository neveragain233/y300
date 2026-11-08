import 'comic/comic_title_number_parser.dart';

/// 目录检索用的章节标记，不改变作品识别、章节身份或既有读序。
final class ChapterSearchMarker {
  const ChapterSearchMarker(this.number, {this.segment});

  final double number;
  final int? segment;

  static const _numbers =
      r'[0-9零〇一二两兩三四五六七八九十百千]+(?:[.点點][0-9零〇一二两兩三四五六七八九]+)?';
  static final _query = RegExp('^第?\\s*($_numbers)\\s*[章话話回节節]?\\s*([①-⑳])?\$');
  static final _explicit = RegExp(
    '(?:第\\s*)?($_numbers)\\s*[章话話回节節]\\s*([①-⑳])?',
  );
  static final _leading = RegExp('^\\s*($_numbers)\\s*([①-⑳])?(?=[、:：.)\\]】])');

  static String normalize(String text) => String.fromCharCodes(
    text.runes.map(
      (rune) => rune >= 0xff01 && rune <= 0xff5e
          ? rune - 0xfee0
          : rune == 0x3000
          ? 0x20
          : rune,
    ),
  ).toLowerCase().trim();

  static ChapterSearchMarker? fromQuery(String text) =>
      _parse(_query.firstMatch(normalize(text)));

  static ChapterSearchMarker? fromTitle(String text) {
    final normalized = normalize(text);
    // 章号标记优先于标题中的年份、书名数字和卷号。
    final explicit = _explicit.allMatches(normalized).lastOrNull;
    return _parse(
      explicit ??
          _query.firstMatch(normalized) ??
          _leading.firstMatch(normalized),
    );
  }

  static ChapterSearchMarker? _parse(RegExpMatch? match) {
    if (match == null) return null;
    const parser = ComicTitleNumberParser();
    final parts = match.group(1)!.split(RegExp('[.点點]'));
    final integer = parser.parseNumber(parts.first);
    if (integer == null) return null;
    var number = integer;
    if (parts.length == 2) {
      final digits = parts.last.split('').map(parser.parseNumber).toList();
      if (digits.any((digit) => digit == null || digit > 9)) return null;
      number += double.parse(
        '0.${digits.map((digit) => digit!.toInt()).join()}',
      );
    }
    final segmentText = match.group(2);
    return ChapterSearchMarker(
      number,
      segment: segmentText == null
          ? null
          : segmentText.runes.single - 0x2460 + 1,
    );
  }
}

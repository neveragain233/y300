import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../contracts/forum_blacklist.dart';
import '../contracts/forum_resource.dart';

/// One validated web-blacklist page.
final class DiscuzForumBlacklistPage {
  /// Creates a page with an optional next-page link proven by the source.
  const DiscuzForumBlacklistPage({
    required this.entries,
    required this.nextPageUri,
    this.deleteUrisByUserId = const <String, Uri>{},
  });

  /// Blacklisted users on this page, in source order.
  final List<ForumBlacklistEntry> entries;

  /// Validated same-list next page, or null when this is the last page.
  final Uri? nextPageUri;

  /// Validated same-origin delete links keyed by target user id.
  final Map<String, Uri> deleteUrisByUserId;
}

/// Parses Discuz's desktop `home.php?mod=space&do=friend&view=blacklist` page.
///
/// The blacklist form is the page shell marker: it is present for an explicit
/// empty list and absent from login or error pages. Any unparseable identity
/// fails the whole page instead of publishing a partial list.
final class DiscuzForumBlacklistParser {
  /// Creates a parser bound to the managed forum origin.
  const DiscuzForumBlacklistParser({required this.siteOrigin});

  /// Managed forum origin.
  final Uri siteOrigin;

  /// Parses one response for [requestUri].
  DiscuzForumBlacklistPage parse({
    required String html,
    required Uri requestUri,
  }) {
    final document = html_parser.parse(html);
    final form = document.querySelector('form[name="blackform"]');
    if (form == null) {
      throw const FormatException('blacklist_shell');
    }
    final action = form.attributes['action'];
    final actionUri = action == null ? null : Uri.tryParse(action);
    if (actionUri == null) {
      throw const FormatException('blacklist_shell');
    }
    final resolvedAction = requestUri.resolveUri(actionUri);
    final actionQuery = resolvedAction.queryParameters;
    if (actionQuery['mod'] != 'spacecp' ||
        actionQuery['ac'] != 'friend' ||
        actionQuery['op'] != 'blacklist') {
      throw const FormatException('blacklist_shell');
    }

    final allFriendRows = document.querySelectorAll('li[id^="friend_"]');
    final container = document.querySelector('#friend_ul');
    final rows = container == null
        ? const <html_dom.Element>[]
        : container.querySelectorAll('li[id^="friend_"]');
    if (container == null && allFriendRows.isNotEmpty) {
      throw const FormatException('blacklist_container');
    }
    if (container != null && rows.length != allFriendRows.length) {
      throw const FormatException('blacklist_container');
    }

    final entries = <ForumBlacklistEntry>[];
    final deleteUrisByUserId = <String, Uri>{};
    final seen = <String>{};
    final resourceResolver = ForumResourceReferenceResolver(
      siteOrigin: siteOrigin,
    );
    for (final row in rows) {
      final idMatch = RegExp(r'^friend_([1-9]\d{0,19})_li$').firstMatch(row.id);
      if (idMatch == null) {
        throw const FormatException('blacklist_identity');
      }
      final userId = idMatch.group(1)!;
      html_dom.Element? nameAnchor;
      for (final anchor in row.querySelectorAll('h4 a[href]')) {
        final href = anchor.attributes['href'];
        if (href == null) {
          continue;
        }
        final uri = _resolve(requestUri, href);
        if (uri == null || _profileUserId(uri) != userId) {
          continue;
        }
        nameAnchor = anchor;
        break;
      }
      if (nameAnchor == null) {
        throw const FormatException('blacklist_identity');
      }
      final username = nameAnchor.text.trim();
      if (username.isEmpty ||
          username.length > 256 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(username)) {
        throw const FormatException('blacklist_username');
      }
      if (!seen.add(userId)) {
        throw const FormatException('blacklist_duplicate_identity');
      }
      final avatarSrc = row
          .querySelector('img.user_avatar[src]')
          ?.attributes['src'];
      final avatarUrl = avatarSrc == null
          ? null
          : resourceResolver.resolve(avatarSrc)?.uri.toString();
      final deleteUri = _deleteActionUri(
        row,
        requestUri: requestUri,
        userId: userId,
      );
      if (deleteUri != null) {
        deleteUrisByUserId[userId] = deleteUri;
      }
      entries.add(
        ForumBlacklistEntry(
          userId: userId,
          username: username,
          avatarUrl: avatarUrl,
        ),
      );
    }

    return DiscuzForumBlacklistPage(
      entries: List<ForumBlacklistEntry>.unmodifiable(entries),
      nextPageUri: _nextPageUri(document, requestUri),
      deleteUrisByUserId: Map<String, Uri>.unmodifiable(deleteUrisByUserId),
    );
  }

  Uri? _deleteActionUri(
    html_dom.Element row, {
    required Uri requestUri,
    required String userId,
  }) {
    for (final anchor in row.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null) {
        continue;
      }
      final uri = _resolve(requestUri, href);
      if (uri == null || !_isSameSite(uri) || !uri.path.endsWith('/home.php')) {
        continue;
      }
      final query = uri.queryParameters;
      final uidValues = uri.queryParametersAll['uid'];
      if (query['mod'] == 'spacecp' &&
          query['ac'] == 'friend' &&
          query['op'] == 'blacklist' &&
          query['subop'] == 'delete' &&
          uidValues != null &&
          uidValues.length == 1 &&
          uidValues.single == userId) {
        return uri;
      }
    }
    return null;
  }

  Uri? _nextPageUri(html_dom.Document document, Uri requestUri) {
    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null) {
        continue;
      }
      final uri = _resolve(requestUri, href);
      if (uri == null || !_isBlacklistPageUri(uri)) {
        continue;
      }
      if (anchor.classes.contains('nxt')) {
        return uri;
      }
    }
    // Discuz renders the same pager anchor with a localized label when the
    // class is absent in a customized template.
    for (final anchor in document.querySelectorAll('a[href]')) {
      final label = anchor.text.trim();
      if (label != '下一页' && label != '下页') {
        continue;
      }
      final href = anchor.attributes['href'];
      if (href == null) {
        continue;
      }
      final uri = _resolve(requestUri, href);
      if (uri != null && _isBlacklistPageUri(uri)) {
        return uri;
      }
    }
    return null;
  }

  bool _isBlacklistPageUri(Uri uri) {
    if (!_isSameSite(uri) || !uri.path.endsWith('/home.php')) {
      return false;
    }
    final query = uri.queryParameters;
    if (query['mod'] != 'space' ||
        query['do'] != 'friend' ||
        query['view'] != 'blacklist' ||
        query.containsKey('ac') ||
        query.containsKey('op') ||
        query.containsKey('subop')) {
      return false;
    }
    final page = query['page'];
    final start = query['start'];
    if (page == null && start == null) {
      return false;
    }
    if (page != null && !RegExp(r'^\d{1,6}$').hasMatch(page)) {
      return false;
    }
    if (start != null && !RegExp(r'^\d{1,8}$').hasMatch(start)) {
      return false;
    }
    return true;
  }

  String? _profileUserId(Uri uri) {
    if (!_isSameSite(uri)) {
      return null;
    }
    final pathMatch = RegExp(
      r'/space-uid-([1-9]\d{0,19})\.html$',
    ).firstMatch(uri.path);
    if (pathMatch != null) {
      return pathMatch.group(1);
    }
    if (!uri.path.endsWith('/home.php')) {
      return null;
    }
    final query = uri.queryParameters;
    if (query['mod'] != 'space') {
      return null;
    }
    final uid = query['uid'];
    return uid != null && RegExp(r'^[1-9]\d{0,19}$').hasMatch(uid) ? uid : null;
  }

  Uri? _resolve(Uri requestUri, String href) {
    final parsed = Uri.tryParse(href.trim());
    if (parsed == null || parsed.userInfo.isNotEmpty) {
      return null;
    }
    final resolved = parsed.isAbsolute ? parsed : requestUri.resolveUri(parsed);
    return resolved.scheme == 'http' || resolved.scheme == 'https'
        ? resolved.removeFragment()
        : null;
  }

  bool _isSameSite(Uri uri) =>
      uri.scheme == siteOrigin.scheme &&
      uri.host == siteOrigin.host &&
      uri.port == siteOrigin.port;
}

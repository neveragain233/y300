import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html;

import '../client/forum_client_config.dart';
import '../contracts/data_command_contract.dart';
import '../contracts/data_read_contract.dart';
import '../contracts/forum_blacklist.dart';
import '../contracts/forum_blacklist_command.dart';
import '../network/forum_network.dart';
import '../network/forum_request.dart';
import '../network/forum_request_profile.dart';
import '../network/forum_response.dart';
import '../network/forum_transport.dart';
import 'discuz_forum_blacklist_parser.dart';

/// Discuz web-blacklist remove command on the Host's shared authenticated session.
///
/// The command first walks the live desktop blacklist pages to locate the
/// target row's validated `spacecp&ac=friend&op=blacklist&subop=delete` link,
/// sends that single GET request without following redirects, and only returns
/// applied after a complete blacklist read omits the target user id.
final class DiscuzForumBlacklistRemoveCommand
    implements ForumBlacklistRemoveCommand {
  /// Creates a remove command bound to the managed origin and current session.
  const DiscuzForumBlacklistRemoveCommand({
    required this.config,
    required this.network,
    required this.profiles,
    required this.blacklist,
  });

  /// Managed forum origin.
  final ForumClientConfig config;

  /// Shared authenticated transport.
  final ForumClientNetwork network;

  /// Configured desktop browser identity.
  final ForumRequestProfileResolver profiles;

  /// Complete-list reader used to prove the postcondition.
  final ForumBlacklistRepository blacklist;

  static const int _maxPages = 20;
  static const int _maxBodyLength = 262144;

  @override
  Future<DataCommandResult<ForumBlacklistRemoveReceipt>> execute(
    ForumBlacklistRemoveSubmission submission,
  ) async {
    final userId = submission.userId.trim();
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(userId)) {
      return DataCommandNotSent(
        _failure(
          'blacklist_remove_input_invalid',
          DataCommandFailureKind.validation,
        ),
      );
    }
    if (submission.cancellation?.isCancelled ?? false) {
      return _cancelled();
    }

    final _TargetDiscovery discovery = await _discoverTargetDeleteUri(
      userId: userId,
      cancellation: submission.cancellation,
    );
    switch (discovery) {
      case _TargetDiscoveryError(:final result):
        return result;
      case _TargetDiscoveryFound(:final pageUri, :final deleteUri):
        return _sendDeleteAndVerify(
          userId: userId,
          pageUri: pageUri,
          deleteUri: deleteUri,
          cancellation: submission.cancellation,
        );
    }
  }

  Future<_TargetDiscovery> _discoverTargetDeleteUri({
    required String userId,
    required ForumRequestCancellation? cancellation,
  }) async {
    final baseUri = config.siteOrigin
        .resolve('home.php')
        .replace(
          queryParameters: const <String, String>{
            'mod': 'space',
            'do': 'friend',
            'view': 'blacklist',
          },
        );
    final parser = DiscuzForumBlacklistParser(siteOrigin: config.siteOrigin);
    final seenUserIds = <String>{};
    final visited = <String>{};
    var pagesRead = 0;
    Uri? next = baseUri;

    while (next != null) {
      if (cancellation?.isCancelled ?? false) {
        return _TargetDiscoveryError(_cancelled());
      }
      if (!visited.add(next.toString())) {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_pagination_loop',
              DataCommandFailureKind.unknown,
            ),
          ),
        );
      }
      if (pagesRead >= _maxPages) {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_too_many_pages',
              DataCommandFailureKind.unknown,
            ),
          ),
        );
      }
      final pageUri = next;
      final ForumTransportResult<ForumResponse<Object?>> result;
      try {
        result = await network.send(
          ForumRequest(
            method: ForumRequestMethod.get,
            uri: pageUri,
            context: const ForumRequestContext(
              operation: 'blacklist.remove.discover',
              pageKind: 'profile.blacklist',
            ),
            headers: profiles
                .resolve(ForumRequestProfileKind.desktopHtml, referer: baseUri)
                .headers,
            followRedirects: false,
            cancellation: cancellation,
          ),
        );
      } on Object {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_preparation_failed',
              DataCommandFailureKind.network,
            ),
          ),
        );
      }
      if (cancellation?.isCancelled ?? false) {
        return _TargetDiscoveryError(_cancelled());
      }
      if (result case ForumTransportError(:final failure)) {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_preparation_failed',
              failure.kind == ForumTransportFailureKind.unauthorized
                  ? DataCommandFailureKind.unauthenticated
                  : failure.kind == ForumTransportFailureKind.cancelled
                  ? DataCommandFailureKind.cancelled
                  : DataCommandFailureKind.network,
            ),
          ),
        );
      }
      final response =
          (result as ForumTransportSuccess<ForumResponse<Object?>>).response;
      final statusCode = response.statusCode;
      if (statusCode == null) {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_preparation_failed',
              DataCommandFailureKind.unknown,
            ),
          ),
        );
      }
      if (statusCode == 401 ||
          statusCode == 403 ||
          (statusCode >= 300 && statusCode < 400)) {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_session_unavailable',
              DataCommandFailureKind.unauthenticated,
            ),
          ),
        );
      }
      final body = response.body;
      if (statusCode != 200 ||
          response.uri != pageUri ||
          body is! String ||
          body.length > _maxBodyLength) {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_preparation_failed',
              DataCommandFailureKind.unknown,
            ),
          ),
        );
      }
      final DiscuzForumBlacklistPage page;
      try {
        page = parser.parse(html: body, requestUri: pageUri);
      } on Object {
        return _TargetDiscoveryError(
          DataCommandNotSent(
            _failure(
              'blacklist_remove_preparation_failed',
              DataCommandFailureKind.unknown,
            ),
          ),
        );
      }
      pagesRead++;
      for (final entry in page.entries) {
        if (!seenUserIds.add(entry.userId)) {
          return _TargetDiscoveryError(
            DataCommandNotSent(
              _failure(
                'blacklist_remove_duplicate_identity',
                DataCommandFailureKind.unknown,
              ),
            ),
          );
        }
        if (entry.userId == userId) {
          final deleteUri = page.deleteUrisByUserId[userId];
          if (deleteUri == null) {
            return _TargetDiscoveryError(
              DataCommandNotSent(
                _failure(
                  'blacklist_remove_action_unavailable',
                  DataCommandFailureKind.validation,
                ),
              ),
            );
          }
          return _TargetDiscoveryFound(pageUri: pageUri, deleteUri: deleteUri);
        }
      }
      next = page.nextPageUri;
    }

    return _TargetDiscoveryError(
      DataCommandRejected(
        _failure(
          'blacklist_remove_not_listed',
          DataCommandFailureKind.validation,
        ),
      ),
    );
  }

  Future<DataCommandResult<ForumBlacklistRemoveReceipt>> _sendDeleteAndVerify({
    required String userId,
    required Uri pageUri,
    required Uri deleteUri,
    required ForumRequestCancellation? cancellation,
  }) async {
    final ForumTransportResult<ForumResponse<Object?>> transport;
    try {
      transport = await network.send(
        ForumRequest(
          method: ForumRequestMethod.get,
          uri: deleteUri,
          context: const ForumRequestContext(
            operation: 'blacklist.remove',
            pageKind: 'profile.blacklist',
          ),
          headers: profiles
              .resolve(ForumRequestProfileKind.desktopHtml, referer: pageUri)
              .headers,
          followRedirects: false,
          cancellation: cancellation,
        ),
      );
    } on Object {
      return _unknown('blacklist_remove_outcome_unproven');
    }
    if (cancellation?.isCancelled ?? false) {
      return _unknown('blacklist_remove_outcome_unproven');
    }
    if (transport case ForumTransportError()) {
      return _unknown('blacklist_remove_outcome_unproven');
    }
    final response =
        (transport as ForumTransportSuccess<ForumResponse<Object?>>).response;
    final statusCode = response.statusCode;
    if (statusCode == null) {
      return _unknown('blacklist_remove_outcome_unproven');
    }
    if (statusCode == 401 || statusCode == 403) {
      return DataCommandRejected(
        _failure(
          'blacklist_remove_session_unavailable',
          DataCommandFailureKind.unauthenticated,
        ),
      );
    }
    if (statusCode >= 300 && statusCode < 400) {
      final location = _locationHeader(response.headers);
      if (location == null ||
          !_isBlacklistSuccessUri(
            _resolve(response.uri, location),
            requestUri: deleteUri,
          )) {
        return _unknown('blacklist_remove_outcome_unproven');
      }
      return _verifyRemoved(userId: userId, cancellation: cancellation);
    }
    final body = response.body;
    if (statusCode != 200 || body is! String || body.length > _maxBodyLength) {
      return _unknown('blacklist_remove_outcome_unproven');
    }
    final document = html.parse(body);
    if (_isLoginPage(document)) {
      return DataCommandRejected(
        _failure(
          'blacklist_remove_session_unavailable',
          DataCommandFailureKind.unauthenticated,
        ),
      );
    }
    if (_hasErrorAlert(document)) {
      return DataCommandRejected(
        _failure(
          'blacklist_remove_rejected',
          DataCommandFailureKind.validation,
        ),
      );
    }
    if (_hasSuccessAlert(document)) {
      return _verifyRemoved(userId: userId, cancellation: cancellation);
    }
    return _unknown('blacklist_remove_outcome_unproven');
  }

  Future<DataCommandResult<ForumBlacklistRemoveReceipt>> _verifyRemoved({
    required String userId,
    required ForumRequestCancellation? cancellation,
  }) async {
    final DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>
    read;
    try {
      read = await blacklist.load(
        ForumBlacklistQuery(cancellation: cancellation),
      );
    } on Object {
      return _unknown('blacklist_remove_verification_unavailable');
    }
    final data = read.dataOrNull;
    if (data == null) {
      return _unknown('blacklist_remove_verification_unavailable');
    }
    if (data.entries.any((entry) => entry.userId == userId)) {
      return _unknown('blacklist_remove_outcome_unproven');
    }
    return DataCommandApplied(ForumBlacklistRemoveReceipt(userId: userId));
  }
}

sealed class _TargetDiscovery {}

final class _TargetDiscoveryFound extends _TargetDiscovery {
  _TargetDiscoveryFound({required this.pageUri, required this.deleteUri});
  final Uri pageUri;
  final Uri deleteUri;
}

final class _TargetDiscoveryError extends _TargetDiscovery {
  _TargetDiscoveryError(this.result);
  final DataCommandResult<ForumBlacklistRemoveReceipt> result;
}

String? _locationHeader(Map<String, List<String>> headers) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() != 'location') continue;
    if (entry.value.length != 1) return null;
    final value = entry.value.single.trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

Uri? _resolve(Uri requestUri, String location) {
  final parsed = Uri.tryParse(location);
  if (parsed == null || parsed.userInfo.isNotEmpty) return null;
  return parsed.isAbsolute ? parsed : requestUri.resolveUri(parsed);
}

bool _isBlacklistSuccessUri(Uri? uri, {required Uri requestUri}) {
  if (uri == null || uri.scheme != requestUri.scheme) return false;
  if (uri.host != requestUri.host || uri.port != requestUri.port) return false;
  if (!uri.path.endsWith('/home.php')) return false;
  final query = uri.queryParameters;
  if (query['mod'] != 'space' ||
      query['do'] != 'friend' ||
      query['view'] != 'blacklist' ||
      query['quickforward'] != '1') {
    return false;
  }
  if (query.containsKey('ac') ||
      query.containsKey('op') ||
      query.containsKey('subop')) {
    return false;
  }
  final uid = query['uid'];
  return uid != null && RegExp(r'^[1-9]\d{0,19}$').hasMatch(uid);
}

bool _hasSuccessAlert(html_dom.Document document) =>
    document.querySelector('#messagetext.alert_right') != null ||
    document.querySelector('div.alert_right') != null;

bool _hasErrorAlert(html_dom.Document document) =>
    document.querySelector('#messagetext.alert_error') != null ||
    document.querySelector('div.alert_error') != null;

bool _isLoginPage(html_dom.Document document) =>
    document.querySelector('#messagelogin') != null ||
    document.querySelector('form#loginform') != null ||
    document.querySelector('form[action*="member.php?mod=logging"]') != null;

DataCommandFailure _failure(String code, DataCommandFailureKind kind) =>
    DataCommandFailure(
      kind: kind,
      retryPolicy: DataCommandRetryPolicy.explicitOnly,
      code: code,
      diagnosticMessage: code,
    );

DataCommandNotSent<ForumBlacklistRemoveReceipt> _cancelled() =>
    DataCommandNotSent(
      _failure('request_cancelled', DataCommandFailureKind.cancelled),
    );

DataCommandOutcomeUnknown<ForumBlacklistRemoveReceipt> _unknown(String code) =>
    DataCommandOutcomeUnknown(_failure(code, DataCommandFailureKind.unknown));

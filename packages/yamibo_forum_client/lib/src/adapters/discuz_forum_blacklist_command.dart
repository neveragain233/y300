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
import '../session/forum_formhash_provider.dart';

/// Discuz web-blacklist add command on the Host's shared authenticated session.
///
/// The submitted form is the live desktop page: `blacklistsubmit`,
/// `blacklistsubmit_btn`, `username` and the session `formhash`, posted to
/// `home.php?mod=spacecp&ac=friend&op=blacklist&start=`. The server answers
/// with either a quick-forward redirect or an alert page; both are only
/// treated as applied after a complete blacklist read lists the target.
final class DiscuzForumBlacklistCommand implements ForumBlacklistCommand {
  /// Creates an add command bound to the managed origin and current session.
  const DiscuzForumBlacklistCommand({
    required this.config,
    required this.network,
    required this.profiles,
    required this.formhash,
    required this.blacklist,
  });

  /// Managed forum origin.
  final ForumClientConfig config;

  /// Shared authenticated transport.
  final ForumClientNetwork network;

  /// Configured desktop browser identity.
  final ForumRequestProfileResolver profiles;

  /// Shared current-session formhash resolver.
  final ForumFormhashProvider formhash;

  /// Complete-list reader used to prove the postcondition.
  final ForumBlacklistRepository blacklist;

  static const int _maxBodyLength = 262144;

  @override
  Future<DataCommandResult<ForumBlacklistAddReceipt>> execute(
    ForumBlacklistAddSubmission submission,
  ) async {
    final userId = submission.userId.trim();
    final username = submission.username;
    if (!RegExp(r'^[1-9]\d{0,19}$').hasMatch(userId) ||
        username.isEmpty ||
        username.length > 256 ||
        username.trim() != username ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(username)) {
      return DataCommandNotSent(
        _failure(
          'blacklist_add_input_invalid',
          DataCommandFailureKind.validation,
        ),
      );
    }
    if (submission.cancellation?.isCancelled ?? false) return _cancelled();

    final ForumFormhashResult hashResult;
    try {
      hashResult = await formhash.loadFormhash(
        cancellation: submission.cancellation,
      );
    } on Object {
      return DataCommandNotSent(
        _failure(
          'blacklist_add_preparation_failed',
          DataCommandFailureKind.unknown,
        ),
      );
    }
    if (submission.cancellation?.isCancelled ?? false) return _cancelled();
    if (hashResult case ForumFormhashError(:final failure)) {
      return DataCommandNotSent(
        _failure(
          'blacklist_add_session_unavailable',
          failure.kind == ForumTransportFailureKind.unauthorized
              ? DataCommandFailureKind.unauthenticated
              : DataCommandFailureKind.staleFormhash,
        ),
      );
    }
    final hash = (hashResult as ForumFormhashSuccess).value.trim();
    if (hash.isEmpty) {
      return DataCommandNotSent(
        _failure('formhash_unavailable', DataCommandFailureKind.staleFormhash),
      );
    }

    final referer = config.siteOrigin
        .resolve('home.php')
        .replace(
          queryParameters: const {
            'mod': 'space',
            'do': 'friend',
            'view': 'blacklist',
          },
        );
    final uri = config.siteOrigin
        .resolve('home.php')
        .replace(
          queryParameters: const {
            'mod': 'spacecp',
            'ac': 'friend',
            'op': 'blacklist',
            'start': '',
          },
        );
    final ForumTransportResult<ForumResponse<Object?>> transport;
    try {
      transport = await network.send(
        ForumRequest(
          method: ForumRequestMethod.post,
          uri: uri,
          context: const ForumRequestContext(
            operation: 'blacklist.add',
            pageKind: 'profile.blacklist',
          ),
          headers: {
            ...profiles
                .resolve(ForumRequestProfileKind.desktopHtml, referer: referer)
                .headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'formhash': hash,
            'username': username,
            'blacklistsubmit': 'true',
            'blacklistsubmit_btn': 'true',
          },
          followRedirects: false,
          cancellation: submission.cancellation,
        ),
      );
    } on Object {
      return _unknown('blacklist_add_outcome_unproven');
    }
    if (submission.cancellation?.isCancelled ?? false) {
      return _unknown('blacklist_add_outcome_unproven');
    }
    if (transport case ForumTransportError()) {
      return _unknown('blacklist_add_outcome_unproven');
    }
    final response =
        (transport as ForumTransportSuccess<ForumResponse<Object?>>).response;
    final statusCode = response.statusCode;
    if (statusCode == null) {
      return _unknown('blacklist_add_outcome_unproven');
    }
    if (statusCode == 401 || statusCode == 403) {
      return DataCommandRejected(
        _failure(
          'blacklist_add_session_unavailable',
          DataCommandFailureKind.unauthenticated,
        ),
      );
    }
    final body = response.body;
    if (statusCode >= 300 && statusCode < 400) {
      final location = _locationHeader(response.headers);
      if (location == null ||
          !_isBlacklistSuccessUri(
            _resolve(response.uri, location),
            requestUri: uri,
          )) {
        return _unknown('blacklist_add_outcome_unproven');
      }
      return _verifyListed(submission);
    }
    if (statusCode != 200 || body is! String || body.length > _maxBodyLength) {
      return _unknown('blacklist_add_outcome_unproven');
    }
    final document = html.parse(body);
    if (_isLoginPage(document)) {
      return DataCommandRejected(
        _failure(
          'blacklist_add_session_unavailable',
          DataCommandFailureKind.unauthenticated,
        ),
      );
    }
    if (_hasErrorAlert(document)) {
      return DataCommandRejected(
        _failure('blacklist_add_rejected', DataCommandFailureKind.validation),
      );
    }
    if (_hasSuccessAlert(document)) {
      return _verifyListed(submission);
    }
    return _unknown('blacklist_add_outcome_unproven');
  }

  Future<DataCommandResult<ForumBlacklistAddReceipt>> _verifyListed(
    ForumBlacklistAddSubmission submission,
  ) async {
    final DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>
    read;
    try {
      read = await blacklist.load(
        ForumBlacklistQuery(cancellation: submission.cancellation),
      );
    } on Object {
      return _unknown('blacklist_add_verification_unavailable');
    }
    final data = read.dataOrNull;
    if (data == null) {
      return _unknown('blacklist_add_verification_unavailable');
    }
    for (final entry in data.entries) {
      if (entry.userId != submission.userId) continue;
      if (entry.username != submission.username) {
        return _unknown('blacklist_add_identity_mismatch');
      }
      return DataCommandApplied(
        ForumBlacklistAddReceipt(
          userId: entry.userId,
          username: entry.username,
        ),
      );
    }
    return _unknown('blacklist_add_outcome_unproven');
  }
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

/// Accepts the exact quick-forward target produced by spacecp_friend.php.
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

DataCommandNotSent<ForumBlacklistAddReceipt> _cancelled() => DataCommandNotSent(
  _failure('request_cancelled', DataCommandFailureKind.cancelled),
);

DataCommandOutcomeUnknown<ForumBlacklistAddReceipt> _unknown(String code) =>
    DataCommandOutcomeUnknown(_failure(code, DataCommandFailureKind.unknown));

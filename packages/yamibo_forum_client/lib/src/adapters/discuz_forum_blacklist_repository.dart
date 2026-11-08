import '../client/forum_client_config.dart';
import '../contracts/data_read_contract.dart';
import '../contracts/forum_blacklist.dart';
import '../network/forum_network.dart';
import '../network/forum_request.dart';
import '../network/forum_request_profile.dart';
import '../network/forum_response.dart';
import '../network/forum_transport.dart';
import 'discuz_forum_blacklist_parser.dart';

/// Desktop web-blacklist source on the Host's authenticated transport.
///
/// The source follows only validated same-list pager anchors, accepts every
/// page or none, and never caches private account data.
final class DiscuzForumBlacklistRepository implements ForumBlacklistRepository {
  /// Creates an uncached source bound to the managed forum origin.
  const DiscuzForumBlacklistRepository({
    required this.config,
    required this.network,
    required this.profiles,
  });

  /// Managed forum origin.
  final ForumClientConfig config;

  /// Shared transport, including the Host's Cookie and cancellation handling.
  final ForumClientNetwork network;

  /// Configured desktop browser identity.
  final ForumRequestProfileResolver profiles;

  static const int _maxPages = 20;
  static const int _maxBodyLength = 262144;

  @override
  ForumBlacklistSourceCapabilities get capabilities =>
      ForumBlacklistSourceCapabilities(
        values: DataCapabilitySet.supported(ForumBlacklistCapability.values),
      );

  @override
  Future<DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>>
  load(ForumBlacklistQuery query) async {
    final baseUri = config.siteOrigin
        .resolve('home.php')
        .replace(
          queryParameters: <String, String>{
            'mod': 'space',
            'do': 'friend',
            'view': 'blacklist',
          },
        );
    final parser = DiscuzForumBlacklistParser(siteOrigin: config.siteOrigin);
    final entries = <ForumBlacklistEntry>[];
    final seenUserIds = <String>{};
    final visited = <String>{};
    var pagesRead = 0;
    Uri? next = baseUri;

    while (next != null) {
      if (query.cancellation?.isCancelled ?? false) {
        return _cancelled();
      }
      if (!visited.add(next.toString())) {
        return _failure('blacklist_pagination_loop', DataReadFailureKind.parse);
      }
      if (pagesRead >= _maxPages) {
        return _failure(
          'blacklist_too_many_pages',
          DataReadFailureKind.business,
        );
      }
      final uri = next;
      final ForumTransportResult<ForumResponse<Object?>> result;
      try {
        result = await network.send(
          ForumRequest(
            method: ForumRequestMethod.get,
            uri: uri,
            context: const ForumRequestContext(
              operation: 'blacklist.read',
              pageKind: 'profile.blacklist',
            ),
            headers: profiles
                .resolve(ForumRequestProfileKind.desktopHtml, referer: baseUri)
                .headers,
            followRedirects: false,
            cancellation: query.cancellation,
          ),
        );
      } on Object {
        return _failure(
          'blacklist_transport_failed',
          DataReadFailureKind.network,
        );
      }
      if (query.cancellation?.isCancelled ?? false) {
        return _cancelled();
      }
      if (result case ForumTransportError(:final failure)) {
        return _failure(
          'blacklist_transport_failed',
          toReadFailureKind(failure.kind),
        );
      }
      final response =
          (result as ForumTransportSuccess<ForumResponse<Object?>>).response;
      final statusCode = response.statusCode;
      if (statusCode == null) {
        return _failure(
          'blacklist_response_unrecognized',
          DataReadFailureKind.parse,
        );
      }
      if (statusCode == 401 ||
          statusCode == 403 ||
          (statusCode >= 300 && statusCode < 400)) {
        return _failure(
          'blacklist_session_unavailable',
          DataReadFailureKind.unauthorized,
        );
      }
      final body = response.body;
      if (statusCode != 200 ||
          response.uri != uri ||
          body is! String ||
          body.length > _maxBodyLength) {
        return _failure(
          'blacklist_response_unrecognized',
          DataReadFailureKind.parse,
        );
      }
      final DiscuzForumBlacklistPage page;
      try {
        page = parser.parse(html: body, requestUri: uri);
      } on Object {
        return _failure(
          'blacklist_response_unrecognized',
          DataReadFailureKind.parse,
        );
      }
      pagesRead++;
      for (final entry in page.entries) {
        if (!seenUserIds.add(entry.userId)) {
          return _failure(
            'blacklist_duplicate_identity',
            DataReadFailureKind.parse,
          );
        }
        entries.add(entry);
      }
      next = page.nextPageUri;
    }

    return DataReadSuccess(
      data: ForumBlacklistData(
        entries: List<ForumBlacklistEntry>.unmodifiable(entries),
        pagesRead: pagesRead,
      ),
      capabilities: capabilities.toReadCapabilities(),
      metadata: const DataReadMetadata.network(),
    );
  }
}

DataReadFailure<ForumBlacklistData, ForumBlacklistReadCapabilities> _failure(
  String code,
  DataReadFailureKind kind,
) => DataReadFailure(kind: kind, code: code, diagnosticMessage: code);

DataReadFailure<ForumBlacklistData, ForumBlacklistReadCapabilities>
_cancelled() => _failure('request_cancelled', DataReadFailureKind.cancelled);

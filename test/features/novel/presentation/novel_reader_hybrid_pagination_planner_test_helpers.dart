part of 'novel_reader_hybrid_pagination_planner_test.dart';

String _visibleText(String html) {
  return (html_parser.parseFragment(html).text ?? '')
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _withoutFormattingWhitespace(String html) {
  return _visibleText(html).replaceAll(RegExp(r'\s+'), '');
}

DefaultNovelReaderHybridPaginationPlanner _planner(
  NovelReaderPaginationMeasureAdapter adapter, {
  NovelReaderFlowableComplexPaginationEngine? flowableComplexEngine,
  NovelReaderPaginationDemand? workDemand,
}) {
  return DefaultNovelReaderHybridPaginationPlanner(
    measureAdapter: adapter,
    preferences: _preferences,
    theme: _theme,
    baseStyle: _baseStyle,
    workDemand: workDemand,
    flowableComplexEngine: flowableComplexEngine,
    validationPolicy: const NovelReaderPaginationValidationPolicy(interval: 8),
  );
}

List<Object?> _anchorValues(NovelReaderTextAnchor anchor) => [
  anchor.episodeId,
  anchor.nodeId,
  anchor.textOffset,
  anchor.pageIndex,
  anchor.scrollOffset,
  anchor.progressPercent,
  anchor.formatVersion,
  anchor.textIdentity,
  anchor.isProgressPercentValid,
];

final class _DemandMeasureSessionFactory
    implements
        NovelReaderPaginationMeasureAdapter,
        NovelReaderPaginationMeasureSessionFactory {
  _DemandMeasureSessionFactory(this.adapter);

  final _RecordingMeasureAdapter adapter;
  final sessions = <_DemandMeasureSession>[];

  @override
  NovelReaderPaginationMeasureSession create({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) {
    final session = _DemandMeasureSession(adapter);
    sessions.add(session);
    return session;
  }

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) => adapter.measure(request);
}

final class _DemandMeasureSession
    implements NovelReaderPaginationMeasureSession {
  _DemandMeasureSession(this.adapter);

  final _RecordingMeasureAdapter adapter;
  int disposeCalls = 0;

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) => adapter.measure(request);

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}

final class _RejectingFlowableEngine
    implements NovelReaderFlowableComplexPaginationEngine {
  const _RejectingFlowableEngine(this.code);

  final String code;

  @override
  Future<NovelReaderFlowableComplexPaginationResult> paginate({
    required NovelReaderClassifiedPaginationAtom atom,
    required NovelReaderPaginationPageContext page,
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
    required NovelReaderPaginationMeasureSession measureSession,
    required NovelReaderPaginationCancellationToken cancellationToken,
    NovelReaderFlowableComplexChunkConsumer? onChunk,
  }) async {
    throw NovelReaderPaginationException(
      code: code,
      message: 'Controlled bounded engine failure.',
    );
  }
}

Future<NovelReaderPreparedChapter> _prepare(String html) {
  const episode = NovelEpisodeItem(
    episodeId: 'hybrid-episode',
    novelId: 'hybrid-novel',
    sourceTid: '100',
    episodeTitle: '混合分页',
    orderIndex: 0,
  );
  return const DefaultNovelReaderHtmlPreparationService().prepare(
    rawHtml: html,
    episode: episode,
    preferences: _preferences,
    theme: _theme,
    sourceId: episode.episodeId,
    threadId: episode.sourceTid,
    imageCacheOwnerId: episode.sourceTid,
  );
}

NovelReaderPaginationKey _key(
  NovelReaderPreparedChapter chapter, {
  required int height,
}) {
  return NovelReaderPaginationKey(
    episodeId: chapter.episodeId,
    contentHash: chapter.contentHash,
    viewportWidthPx: 320,
    viewportHeightPx: height,
    typographySignature: 'font=18.5|line=1.6|hybrid',
    themeSignature: chapter.themeSignature,
    imageDimensionRevision: chapter.imageDimensionRevision,
    rendererRevision: 3,
  );
}

typedef _HeightFor = double Function(
  NovelReaderPaginationMeasureRequest request,
  int validationCall,
);

final class _RecordingMeasureAdapter
    implements NovelReaderPaginationMeasureAdapter {
  _RecordingMeasureAdapter({this.heightFor, this.beforeMeasure});

  final _HeightFor? heightFor;
  final Future<void> Function(NovelReaderPaginationMeasureRequest)?
  beforeMeasure;
  int calls = 0;
  int validationCalls = 0;
  final List<NovelReaderPaginationMeasureRequest> requests =
      <NovelReaderPaginationMeasureRequest>[];

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) async {
    calls += 1;
    requests.add(request);
    if (request.atomId?.endsWith(':validation') == true) {
      validationCalls += 1;
    }
    final beforeMeasure = this.beforeMeasure;
    if (beforeMeasure != null) {
      await beforeMeasure(request);
    }
    return NovelReaderPaginationMeasureResult(
      height: heightFor?.call(request, validationCalls) ?? 10,
    );
  }
}

final class _GatedValidationMeasureAdapter
    implements NovelReaderPaginationMeasureAdapter {
  _GatedValidationMeasureAdapter({this.laterHeight = 10});

  final Completer<void> _laterValidationGate = Completer<void>();
  final double laterHeight;
  int validationCalls = 0;
  bool laterValidationStarted = false;

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) async {
    if (request.atomId?.endsWith(':validation') == true) {
      validationCalls += 1;
      if (validationCalls == 2) {
        laterValidationStarted = true;
        await _laterValidationGate.future;
      }
    }
    return NovelReaderPaginationMeasureResult(
      height: validationCalls >= 2 ? laterHeight : 10,
    );
  }

  void releaseLaterValidation() {
    if (!_laterValidationGate.isCompleted) {
      _laterValidationGate.complete();
    }
  }
}

final class _GatedSessionFactory
    implements
        NovelReaderPaginationMeasureAdapter,
        NovelReaderPaginationMeasureSessionFactory {
  _GatedSessionFactory({bool disposeCompletesError = false})
    : session = _GatedLifecycleMeasureSession(disposeCompletesError);

  final _GatedLifecycleMeasureSession session;

  @override
  NovelReaderPaginationMeasureSession create({
    required NovelReaderPreparedChapter chapter,
    required NovelReaderPaginationKey key,
  }) => session;

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) => session.measure(request);
}

final class _GatedLifecycleMeasureSession
    implements NovelReaderPaginationMeasureSession {
  _GatedLifecycleMeasureSession(this.disposeCompletesError);

  final bool disposeCompletesError;
  final started = Completer<void>();
  final result = Completer<NovelReaderPaginationMeasureResult>();
  int measureCalls = 0;
  int disposeCalls = 0;

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) {
    measureCalls += 1;
    if (!started.isCompleted) started.complete();
    return result.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    if (disposeCompletesError && !result.isCompleted) {
      result.completeError(
        const NovelReaderPaginationException(
          code: 'measurementSessionDisposed',
          message: 'Controlled probe disposal.',
        ),
      );
    }
  }
}

final class _ThrowingTextStyleResolver implements ForumHtmlTextStyleResolver {
  const _ThrowingTextStyleResolver();

  @override
  ForumHtmlResolvedTextStyle resolve({
    required html_dom.Element element,
    required TextStyle parentStyle,
    required TextStyle baseStyle,
    required ForumHtmlReaderPreferences preferences,
    required ForumHtmlThemeContext theme,
  }) {
    throw StateError('synthetic text layout failure');
  }
}

final class _ThrowingCompositionMeasureAdapter
    implements NovelReaderPaginationMeasureAdapter {
  const _ThrowingCompositionMeasureAdapter();

  @override
  Future<NovelReaderPaginationMeasureResult> measure(
    NovelReaderPaginationMeasureRequest request,
  ) async {
    if (request.atomId?.contains(':composition:validation') == true) {
      throw StateError('synthetic composition validation failure');
    }
    return NovelReaderPaginationMeasureResult(
      height: request.html.contains('<table>') ? 24 : 30,
    );
  }
}

const _preferences = ForumHtmlReaderPreferences(
  typography: RichTextTypography(
    fontScale: 18.5 / 14,
    lineHeightScale: 1.6,
    paragraphSpacing: 12,
  ),
  conversionMode: TextConversionMode.none,
);

const _baseStyle = TextStyle(
  color: Color(0xFF4C3A21),
  fontSize: 18.5,
  height: 1.6,
);

const _theme = ForumHtmlThemeContext(
  brightness: ForumHtmlBrightness.light,
  surface: Color(0xFFF4EAD7),
  foreground: Color(0xFF4C3A21),
  link: Color(0xFF6A55A3),
  quoteSurface: Color(0xFFE8D8B8),
  quoteForeground: Color(0xFF8B7355),
  codeSurface: Color(0xFFEFE0C4),
  codeForeground: Color(0xFF4C3A21),
);

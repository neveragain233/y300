part of 'composer_quill_prototype_editor_test.dart';

void _formattingToolsCases() {
  testWidgets('ComposerQuillPrototypeEditor exposes WYSIWYG toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(_buildEditor());

    expect(find.byKey(const Key('test-quill-format-button')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-align-button')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-quote-button')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-link-button')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-sticker-button')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-image-button')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-bbcode-output')), findsNothing);
    expect(
      find.ancestor(
        of: find.byKey(const Key('test-quill-format-button')),
        matching: find.byWidgetPredicate((widget) {
          return widget is Material &&
              widget.color ==
                  AppTheme.light().colorScheme.surfaceContainerHighest;
        }),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('test-quill-editor')),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) {
            return false;
          }
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.border != null;
        }),
      ),
      findsNothing,
    );
  });

  testWidgets('format button toggles an embedded tool panel', (tester) async {
    await tester.pumpWidget(_buildEditor());

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-quill-tool-panel')), findsOneWidget);
    expect(find.byKey(const Key('test-quill-format-sheet')), findsOneWidget);
    expect(find.text('格式'), findsNothing);
    _expectIconButtonIcon(
      tester,
      const Key('test-quill-format-bold-toggle'),
      Icons.format_bold,
    );
    _expectIconButtonIcon(
      tester,
      const Key('test-quill-format-italic-toggle'),
      Icons.format_italic,
    );
    _expectIconButtonIcon(
      tester,
      const Key('test-quill-format-underline-toggle'),
      Icons.format_underline,
    );
    _expectIconButtonIcon(
      tester,
      const Key('test-quill-format-strike-toggle'),
      Icons.format_strikethrough,
    );
    expect(
      find.byKey(const Key('test-quill-format-clear-state-button')),
      findsOneWidget,
    );
    _expectClearStateOnFormatRow(tester);
    _expectSizeControlsStayOnOneLine(tester);

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
  });

  testWidgets('custom actions share the embedded Quill tool panel', (
    tester,
  ) async {
    final action = ComposerToolbarAction.panel(
      key: const Key('test-quill-custom-panel-button'),
      icon: Icons.collections_outlined,
      tooltip: 'custom panel',
      panelBuilder: (_) =>
          const SizedBox.expand(key: Key('test-quill-custom-panel-content')),
    );
    await tester.pumpWidget(_buildEditor(extraToolbarActions: [action]));

    await tester.tap(find.byKey(const Key('test-quill-custom-panel-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-quill-tool-panel')), findsOneWidget);
    expect(
      find.byKey(const Key('test-quill-custom-panel-content')),
      findsOneWidget,
    );
    expect(_toolbarBottomGap(tester), greaterThan(200));

    final updatedAction = ComposerToolbarAction.panel(
      key: const Key('test-quill-custom-panel-button'),
      icon: Icons.collections_outlined,
      tooltip: 'custom panel',
      panelBuilder: (_) =>
          const SizedBox.expand(key: Key('test-quill-updated-panel-content')),
    );
    await tester.pumpWidget(_buildEditor(extraToolbarActions: [updatedAction]));
    await tester.pump();
    expect(
      find.byKey(const Key('test-quill-updated-panel-content')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-updated-panel-content')),
      findsNothing,
    );
    expect(find.byKey(const Key('test-quill-format-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-quill-custom-panel-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-quill-format-sheet')), findsNothing);
    expect(
      find.byKey(const Key('test-quill-updated-panel-content')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('test-quill-custom-panel-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
  });

  testWidgets(
    'closing the active tool panel keeps toolbar raised until keyboard returns',
    (tester) async {
      const keyboardInsets = EdgeInsets.only(bottom: 320);
      await tester.pumpWidget(_buildEditor(viewInsets: keyboardInsets));
      await tester.pump();

      await tester.tap(find.byKey(const Key('test-quill-format-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_buildEditor());
      await tester.pump();

      expect(find.byKey(const Key('test-quill-tool-panel')), findsOneWidget);
      final panelGap = _toolbarBottomGap(tester);
      expect(panelGap, greaterThan(260));

      await tester.tap(find.byKey(const Key('test-quill-format-button')));
      await tester.pump();

      expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
      final waitingForKeyboardGap = _toolbarBottomGap(tester);
      expect(waitingForKeyboardGap, greaterThan(260));

      await tester.pumpWidget(_buildEditor(viewInsets: keyboardInsets));
      await tester.pump();

      final keyboardGap = _toolbarBottomGap(tester);
      expect(keyboardGap, greaterThan(260));
    },
  );

  testWidgets('an externally opened keyboard dismisses the active tool panel', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_buildEditor(controller: controller));

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-quill-tool-panel')), findsOneWidget);

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        viewInsets: const EdgeInsets.only(bottom: 320),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
    expect(_toolbarBottomGap(tester), greaterThan(260));
  });

  testWidgets('format sheet applies selected text formatting immediately', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    controller.replaceText(
      0,
      0,
      '文字',
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('test-quill-format-apply-button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('test-quill-format-underline-toggle')),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-size-4')),
    );
    await tester.tap(find.byKey(const Key('test-quill-format-size-4')));
    await tester.pump();
    expect(
      controller.getSelectionStyle().attributes[Attribute.size.key]?.value,
      '18',
    );
    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
    );
    await tester.tap(
      find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
    );
    await tester.pump();

    expect(latest, '[b][u][size=4][color=#d32f2f]文字[/color][/size][/u][/b]');
  });

  testWidgets('format options do not refocus the editor until tool closes', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_buildEditor(controller: controller));
    controller.replaceText(
      0,
      0,
      '文字',
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await tester.pump();

    final editorFocusNode = _editorFocusNode(tester);
    editorFocusNode.requestFocus();
    await tester.pump();
    expect(editorFocusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    expect(editorFocusNode.hasFocus, isFalse);

    await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
    await tester.pump();
    expect(editorFocusNode.hasFocus, isFalse);
    await tester.tap(find.byKey(const Key('test-quill-format-italic-toggle')));
    await tester.pump();
    expect(editorFocusNode.hasFocus, isFalse);
    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-size-4')),
    );
    await tester.tap(find.byKey(const Key('test-quill-format-size-4')));
    await tester.pump();
    expect(editorFocusNode.hasFocus, isFalse);
    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
    );
    await tester.tap(
      find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
    );
    await tester.pump();
    expect(editorFocusNode.hasFocus, isFalse);

    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-button')),
    );
    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pump();

    expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
    expect(editorFocusNode.hasFocus, isTrue);
  });

  testWidgets(
    'tapping a normal editor position closes tools and adopts nearby style',
    (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);
      controller.replaceText(
        0,
        0,
        '普通斜体',
        const TextSelection.collapsed(offset: 0),
      );
      controller.formatText(2, 2, Attribute.italic);

      await tester.pumpWidget(_buildEditor(controller: controller));
      await tester.tap(find.byKey(const Key('test-quill-format-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
      await tester.pump();

      _dispatchEditorTap(tester, controller: controller, offset: 3);
      await tester.pump();

      expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
      expect(controller.toggledStyle.isEmpty, isTrue);
      expect(
        controller.getSelectionStyle().attributes[Attribute.italic.key]?.value,
        isTrue,
      );
      expect(
        controller.getSelectionStyle().attributes[Attribute.bold.key],
        isNull,
      );

      await tester.tap(find.byKey(const Key('test-quill-format-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('test-quill-tool-panel')), findsOneWidget);
    },
  );

  testWidgets('tapping document end restores the explicitly selected style', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.replaceText(
      0,
      0,
      '普通末尾',
      const TextSelection.collapsed(offset: 0),
    );
    controller.formatText(2, 2, Attribute.italic);
    controller.formatText(2, 2, Attribute.clone(Attribute.color, '#d32f2f'));

    await tester.pumpWidget(_buildEditor(controller: controller));
    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
    await tester.pump();

    _dispatchEditorTap(tester, controller: controller, offset: 4);
    await tester.pump();
    controller.replaceText(4, 0, '新', const TextSelection.collapsed(offset: 5));
    await tester.pump();

    final insertedStyle = controller.document.collectStyle(4, 1).attributes;
    expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
    expect(insertedStyle[Attribute.bold.key]?.value, isTrue);
    expect(insertedStyle[Attribute.italic.key], isNull);
    expect(insertedStyle[Attribute.color.key], isNull);
  });

  testWidgets(
    'align and sticker tools mutate content without refocusing editor',
    (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);
      String latest = '';

      await tester.pumpWidget(
        _buildEditor(
          controller: controller,
          onBbCodeChanged: (value) => latest = value,
          stickerGroups: _stickerGroups(),
        ),
      );
      final editorFocusNode = _editorFocusNode(tester);
      editorFocusNode.requestFocus();
      await tester.pump();

      await tester.tap(find.byKey(const Key('test-quill-align-button')));
      await tester.pumpAndSettle();
      expect(editorFocusNode.hasFocus, isFalse);
      await tester.tap(find.byKey(const Key('test-quill-align-center')));
      await tester.pump();
      expect(editorFocusNode.hasFocus, isFalse);
      expect(
        _currentLineAlignment(controller),
        Attribute.centerAlignment.value,
      );

      await tester.tap(find.byKey(const Key('test-quill-sticker-button')));
      await tester.pumpAndSettle();
      expect(editorFocusNode.hasFocus, isFalse);
      await tester.tap(
        find.byKey(const Key('test-quill-sticker-item-{:9_656:}')),
      );
      await tester.pump();

      expect(editorFocusNode.hasFocus, isFalse);
      expect(latest, '[align=center]{:9_656:}[/align]');
    },
  );

  testWidgets('format toggles affect future input and can be turned off', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
    await tester.pump();

    controller.replaceText(0, 0, '粗体', null);
    await tester.pump();

    await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
    await tester.pump();
    controller.replaceText(2, 0, '普通', null);
    await tester.pump();

    expect(latest, '[b]粗体[/b]普通');
  });

  testWidgets('active selected text format can be removed immediately', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    controller.replaceText(
      0,
      0,
      '文字',
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    controller.formatSelection(Attribute.bold);
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      ChangeSource.local,
    );
    await tester.pump();
    expect(latest, '[b]文字[/b]');

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
    await tester.pump();

    expect(latest, '文字');
  });

  testWidgets('size color and background clear immediately', (tester) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    controller.replaceText(
      0,
      0,
      '文字',
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-size-4')),
    );
    await tester.tap(find.byKey(const Key('test-quill-format-size-4')));
    await tester.pump();
    expect(latest, '[size=4]文字[/size]');
    expect(
      controller.getSelectionStyle().attributes[Attribute.size.key]?.value,
      '18',
    );

    await tester.tap(find.byKey(const Key('test-quill-format-size-4')));
    await tester.pump();
    expect(latest, '文字');

    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
    );
    await tester.tap(
      find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
    );
    await tester.pump();
    expect(latest, '[color=#d32f2f]文字[/color]');

    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-color-swatch-ffffff')),
    );
    await tester.tap(
      find.byKey(const Key('test-quill-format-color-swatch-ffffff')),
    );
    await tester.pump();
    expect(latest, '[color=#ffffff]文字[/color]');

    await tester.tap(
      find.byKey(const Key('test-quill-format-clear-color-button')),
    );
    await tester.pump();
    expect(latest, '文字');

    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-backcolor-swatch-fff3b0')),
    );
    await tester.tap(
      find.byKey(const Key('test-quill-format-backcolor-swatch-fff3b0')),
    );
    await tester.pump();
    expect(latest, '[backcolor=#fff3b0]文字[/backcolor]');

    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-clear-backcolor-button')),
    );
    await tester.tap(
      find.byKey(const Key('test-quill-format-clear-backcolor-button')),
    );
    await tester.pump();
    expect(latest, '文字');
  });

  testWidgets(
    'clear state removes every managed style from a mixed selection',
    (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);
      String latest = '';

      await tester.pumpWidget(
        _buildEditor(
          controller: controller,
          onBbCodeChanged: (value) => latest = value,
        ),
      );
      controller.replaceText(
        0,
        0,
        '甲乙',
        const TextSelection.collapsed(offset: 2),
      );
      controller.formatText(0, 1, Attribute.bold);
      controller.formatText(0, 1, Attribute.italic);
      controller.formatText(0, 1, Attribute.underline);
      controller.formatText(0, 1, Attribute.strikeThrough);
      controller.formatText(0, 1, Attribute.clone(Attribute.size, '18'));
      controller.formatText(0, 1, Attribute.clone(Attribute.color, '#d32f2f'));
      controller.formatText(
        0,
        1,
        Attribute.clone(Attribute.background, '#fff3b0'),
      );
      controller.formatText(
        0,
        1,
        Attribute.clone(Attribute.link, 'https://example.com'),
      );
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 2),
        ChangeSource.local,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('test-quill-format-button')));
      await tester.pumpAndSettle();
      final clearButton = tester.widget<TextButton>(
        find.byKey(const Key('test-quill-format-clear-state-button')),
      );
      expect(clearButton.onPressed, isNotNull);
      await tester.tap(
        find.byKey(const Key('test-quill-format-clear-state-button')),
      );
      await tester.pump();

      expect(latest, '[url=https://example.com]甲[/url]乙');
    },
  );

  testWidgets('clear state isolates future input at a collapsed caret', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.replaceText(
      0,
      0,
      '末尾',
      const TextSelection.collapsed(offset: 2),
    );
    controller.formatText(0, 2, Attribute.bold);
    controller.formatText(0, 2, Attribute.italic);
    controller.formatText(0, 2, Attribute.clone(Attribute.size, '18'));
    controller.formatText(0, 2, Attribute.clone(Attribute.color, '#d32f2f'));
    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      ChangeSource.local,
    );

    await tester.pumpWidget(_buildEditor(controller: controller));
    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('test-quill-format-clear-state-button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pump();
    controller.replaceText(2, 0, '新', const TextSelection.collapsed(offset: 3));
    await tester.pump();

    final insertedStyle = controller.document.collectStyle(2, 1).attributes;
    expect(insertedStyle[Attribute.bold.key], isNull);
    expect(insertedStyle[Attribute.italic.key], isNull);
    expect(insertedStyle[Attribute.size.key], isNull);
    expect(insertedStyle[Attribute.color.key], isNull);
  });

  testWidgets('size 3 exports normal Discuz size only when selected', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    controller.replaceText(
      0,
      0,
      '文字',
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await tester.pump();
    expect(latest, '文字');

    await tester.tap(find.byKey(const Key('test-quill-format-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('test-quill-format-size-3')),
    );
    await tester.tap(find.byKey(const Key('test-quill-format-size-3')));
    await tester.pump();

    expect(latest, '[size=3]文字[/size]');
    expect(
      controller.getSelectionStyle().attributes[Attribute.size.key]?.value,
      '16',
    );
  });
}

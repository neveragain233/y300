import 'package:flutter/material.dart';
import 'package:y300/features/library_shared/domain/contracts/detail_module_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/presentation/services/library_detail_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/shared/widgets/y300_page_scaffold.dart';

/// 新样式“编辑作品信息”二级页面：整合基本信息、作品简介与章节管理入口。
class UnifiedDetailWorkEditPage extends StatefulWidget {
  const UnifiedDetailWorkEditPage({
    super.key,
    required this.moduleKey,
    required this.initialTitle,
    required this.initialAuthor,
    required this.initialTranslationGroup,
    required this.initialOriginalWork,
    required this.initialSearchTitle,
    required this.initialIntro,
    required this.titleSourceText,
    required this.authorSourceText,
    required this.groupSourceText,
    required this.sourceTranslatorName,
    required this.isTranslatorCustom,
    required this.fields,
    required this.chapterCount,
    required this.onSave,
    this.onOpenChapterManagement,
  });

  final LibraryModuleKey moduleKey;
  final String initialTitle;
  final String initialAuthor;
  final String initialTranslationGroup;
  final String initialOriginalWork;
  final String initialSearchTitle;
  final String initialIntro;
  final String titleSourceText;
  final String authorSourceText;
  final String groupSourceText;

  /// 小说原帖发帖人（未自定义译者时的默认值）。
  final String? sourceTranslatorName;
  final bool isTranslatorCustom;
  final Set<LibraryMetadataField> fields;
  final int chapterCount;

  final Future<void> Function({
    String? customTitle,
    String? customAuthor,
    String? customTranslationGroup,
    String? customOriginalWork,
    String? customSearchTitle,
    required String intro,
  })
  onSave;

  final Future<int?> Function(BuildContext sheetContext)?
  onOpenChapterManagement;

  @override
  State<UnifiedDetailWorkEditPage> createState() =>
      _UnifiedDetailWorkEditPageState();
}

class _UnifiedDetailWorkEditPageState extends State<UnifiedDetailWorkEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _groupController;
  late final TextEditingController _originalWorkController;
  late final TextEditingController _searchController;
  late final TextEditingController _introController;

  late bool _followDefaultTranslator;
  late int _chapterCount;
  bool _saving = false;

  bool get _isNovel => widget.moduleKey == LibraryModuleKey.novel;

  String? get _normalizedDefaultTranslator {
    final raw = widget.sourceTranslatorName?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _authorController = TextEditingController(text: widget.initialAuthor);
    _groupController = TextEditingController(
      text: widget.initialTranslationGroup,
    );
    _originalWorkController = TextEditingController(
      text: widget.initialOriginalWork,
    );
    _searchController = TextEditingController(text: widget.initialSearchTitle);
    _introController = TextEditingController(text: widget.initialIntro);
    _followDefaultTranslator = _isNovel && !widget.isTranslatorCustom;
    _chapterCount = widget.chapterCount;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _groupController.dispose();
    _originalWorkController.dispose();
    _searchController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _onTranslatorChanged(String value) {
    if (!_isNovel) return;
    final defaultName = _normalizedDefaultTranslator;
    final nextFollow = defaultName != null && value.trim() == defaultName;
    if (_followDefaultTranslator != nextFollow) {
      setState(() => _followDefaultTranslator = nextFollow);
    }
  }

  void _restoreDefaultTranslator() {
    final defaultName = _normalizedDefaultTranslator;
    if (defaultName == null) return;
    _groupController.value = TextEditingValue(
      text: defaultName,
      selection: TextSelection.collapsed(offset: defaultName.length),
    );
    if (!_followDefaultTranslator) {
      setState(() => _followDefaultTranslator = true);
    }
  }

  String? _resolveTranslatorForSave() {
    final trimmed = _groupController.text.trim();
    if (_isNovel) {
      if (_followDefaultTranslator) {
        return null;
      }
      // 小说允许显式清空译者（保存为空串），用于作者自发或同人无译者作品。
      return trimmed;
    }
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        customTitle: widget.fields.contains(LibraryMetadataField.title)
            ? _emptyToNull(_titleController.text)
            : null,
        customAuthor: widget.fields.contains(LibraryMetadataField.author)
            ? _emptyToNull(_authorController.text)
            : null,
        customTranslationGroup:
            widget.fields.contains(LibraryMetadataField.translationGroup)
            ? _resolveTranslatorForSave()
            : null,
        customOriginalWork:
            widget.fields.contains(LibraryMetadataField.originalWork)
            ? _emptyToNull(_originalWorkController.text)
            : null,
        customSearchTitle:
            widget.fields.contains(LibraryMetadataField.searchTitle)
            ? _emptyToNull(_searchController.text)
            : null,
        intro: _introController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openChapterManagement() async {
    final handler = widget.onOpenChapterManagement;
    if (handler == null) return;
    final updatedCount = await handler(context);
    if (mounted && updatedCount != null) {
      setState(() => _chapterCount = updatedCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasMetadataFields = widget.fields.isNotEmpty;
    final defaultTranslator = _normalizedDefaultTranslator;
    final showRestoreTranslator =
        _isNovel && defaultTranslator != null && !_followDefaultTranslator;

    return Y300PageScaffold(
      appBar: AppPageAppBar(
        title: l10n.libraryDetailEditMetadata,
        actions: [
          IconButton(
            key: const Key('unified-detail-save-metadata'),
            tooltip: l10n.commonSave,
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        key: const Key('unified-detail-metadata-sheet'),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        children: [
          if (hasMetadataFields)
            AppGroupedSection(
              title: l10n.libraryDetailWorkInfoSection,
              margin: EdgeInsets.zero,
              dividerIndent: 16,
              children: [
                if (widget.fields.contains(LibraryMetadataField.title))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppTextInput(
                      key: const Key('unified-detail-custom-title-input'),
                      controller: _titleController,
                      label: LibraryDetailTextResolver.metadataField(
                        l10n,
                        LibraryMetadataField.title,
                        moduleKey: widget.moduleKey,
                      ),
                      helperText: widget.titleSourceText,
                    ),
                  ),
                if (widget.fields.contains(LibraryMetadataField.author))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppTextInput(
                      key: const Key('unified-detail-custom-author-input'),
                      controller: _authorController,
                      label: LibraryDetailTextResolver.metadataField(
                        l10n,
                        LibraryMetadataField.author,
                        moduleKey: widget.moduleKey,
                      ),
                      helperText: widget.authorSourceText,
                    ),
                  ),
                if (widget.fields.contains(
                  LibraryMetadataField.translationGroup,
                ))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextInput(
                          key: const Key('unified-detail-custom-group-input'),
                          controller: _groupController,
                          label: LibraryDetailTextResolver.metadataField(
                            l10n,
                            LibraryMetadataField.translationGroup,
                            moduleKey: widget.moduleKey,
                          ),
                          helperText: _isNovel && defaultTranslator != null
                              ? l10n.libraryDetailTranslatorHelperWithDefault(
                                  defaultTranslator,
                                )
                              : widget.groupSourceText,
                          onChanged: _onTranslatorChanged,
                        ),
                        if (showRestoreTranslator) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              key: const Key(
                                'unified-detail-restore-default-translator',
                              ),
                              onPressed: _restoreDefaultTranslator,
                              child: Text(l10n.libraryDetailRestoreDefault),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (widget.fields.contains(LibraryMetadataField.originalWork))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppTextInput(
                      key: const Key(
                        'unified-detail-custom-original-work-input',
                      ),
                      controller: _originalWorkController,
                      label: LibraryDetailTextResolver.metadataField(
                        l10n,
                        LibraryMetadataField.originalWork,
                        moduleKey: widget.moduleKey,
                      ),
                      helperText: l10n.libraryDetailOriginalWorkHint,
                    ),
                  ),
                if (widget.fields.contains(LibraryMetadataField.searchTitle))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppTextInput(
                      key: const Key(
                        'unified-detail-custom-search-title-input',
                      ),
                      controller: _searchController,
                      label: LibraryDetailTextResolver.metadataField(
                        l10n,
                        LibraryMetadataField.searchTitle,
                        moduleKey: widget.moduleKey,
                      ),
                      helperText: l10n.libraryDetailMetadataSearchHelp,
                    ),
                  ),
              ],
            ),
          if (hasMetadataFields) const SizedBox(height: 16),
          AppGroupedSection(
            title: l10n.libraryDetailIntroSection,
            margin: EdgeInsets.zero,
            dividerIndent: 16,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppTextInput(
                  key: const Key('unified-detail-intro-input'),
                  controller: _introController,
                  minLines: 4,
                  maxLines: null,
                  hintText: l10n.libraryDetailIntroHint,
                ),
              ),
            ],
          ),
          if (widget.onOpenChapterManagement != null) ...[
            const SizedBox(height: 16),
            AppGroupedSection(
              title: l10n.libraryDetailChaptersSection,
              margin: EdgeInsets.zero,
              children: [
                AppGroupedRow(
                  key: const Key('unified-detail-manage-chapters'),
                  leading: const Icon(Icons.checklist),
                  title: l10n.libraryDetailManageChapters,
                  subtitle: l10n.libraryDetailChapterCountSummary(
                    _chapterCount,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openChapterManagement,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

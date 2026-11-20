import 'package:flutter/material.dart';
import 'package:y300/features/comic/domain/services/comic_source_tag_reader.dart';
import 'package:y300/features/tags/presentation/yamibo_tag_thread_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';

/// Lists a comic's source-thread tags and opens the native tag directory.
Future<void> showComicSourceTagsSheet(
  BuildContext context, {
  required Future<List<ComicSourceTag>> Function() loadTags,
}) async {
  final navigator = Navigator.of(context);
  final l10n = AppLocalizations.of(context);
  // 面板按窗口属主选择底栏或侧栏宿主，与漫画阅读器其它紧凑面板同源；
  // 根导航不变，标签页在关闭面板后压入当前阅读器栈。
  await showAdaptivePanel<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.libraryDetailSourceTags,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: FutureBuilder<List<ComicSourceTag>>(
                  future: loadTags(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          l10n.libraryDetailSourceTagsLoadFailed,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final tags = snapshot.data ?? const <ComicSourceTag>[];
                    if (tags.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.libraryDetailSourceTagsEmpty,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.builder(
                      key: const Key('comic-source-tags-list'),
                      itemCount: tags.length,
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        return ListTile(
                          key: Key('comic-source-tag-${tag.tagId}'),
                          leading: const Icon(Icons.sell_outlined),
                          title: Text(tag.label),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            navigator.pop(sheetContext);
                            navigator.push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    YamiboTagThreadPage(tagId: tag.tagId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

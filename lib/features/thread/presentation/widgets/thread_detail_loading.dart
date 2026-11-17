part of 'thread_detail_widgets.dart';

/// Shared title geometry for entry states before a post list is available.
class ThreadDetailEntrySurface extends StatelessWidget {
  const ThreadDetailEntrySurface({
    super.key,
    required this.subject,
    required this.child,
  });

  final String subject;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = ThreadDetailNativePalette.resolve(Theme.of(context));
    return SingleChildScrollView(
      // Loading/error scrolling must not restore or alter the post position.
      primary: false,
      padding: const EdgeInsets.fromLTRB(
        ForumContentSpacing.readableBodyHorizontal,
        ForumContentSpacing.listTop + ForumContentSpacing.postCardHeaderTop,
        ForumContentSpacing.readableBodyHorizontal,
        ForumContentSpacing.listBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subject.trim().isNotEmpty) ...[
            _FirstPostThreadSummary(subject: subject, palette: palette),
            const SizedBox(height: 11),
          ],
          child,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/features/forum/presentation/forum_home_page.dart';

/// The forum entry shares one UI across all client source profiles.
class ForumShellPage extends StatelessWidget {
  const ForumShellPage({
    super.key,
    this.isActive = true,
    this.browserController,
    this.globalOrigin = Offset.zero,
  });

  final bool isActive;
  final AdaptiveDetailController? browserController;
  final Offset globalOrigin;

  @override
  Widget build(BuildContext context) => AdaptiveDetailHost(
    controller: browserController,
    isActive: isActive,
    globalOrigin: globalOrigin,
    child: ForumHomePage(isActive: isActive),
  );
}

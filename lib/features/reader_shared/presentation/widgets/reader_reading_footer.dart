import 'package:flutter/material.dart';

/// Display-only Efficiency E-Ink reading footer (title + page progress + time).
class ReaderReadingFooter extends StatelessWidget {
  const ReaderReadingFooter({
    super.key,
    required this.title,
    required this.progressText,
    this.dark = false,
  });

  final String title;
  final String progressText;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final bg = dark ? const Color(0xFF141414) : const Color(0xFFFFFFFF);
    final fg = dark ? const Color(0xFFE0E0E0) : const Color(0xFF444444);
    final border = dark ? const Color(0xFF333333) : const Color(0xFFCCCCCC);

    return IgnorePointer(
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: fg, height: 1.1),
              ),
            ),
            if (progressText.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                progressText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              '$hh:$mm',
              style: TextStyle(fontSize: 11, color: fg, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

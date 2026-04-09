import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../providers/courses_provider.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final CourseListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = item.course;
    final fee = c.monthlyFee.toStringAsFixed(0);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: c.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.school_outlined,
                          size: 40,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ColoredBox(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳$fee/মাস',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.studentCount} শিক্ষার্থী',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _StatusChip(active: c.isActive),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF27AE60) : Colors.grey.shade500;
    final label = active ? 'সক্রিয়' : 'নিষ্ক্রিয়';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.hindSiliguri(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: bg,
        ),
      ),
    );
  }
}

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/course_consent_page.dart';
import 'package:e_medrese/presentation/features/courses/review_form_page.dart';
import 'package:e_medrese/presentation/features/report/report_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yıldızlar: [rating] kadar dolu (yarım yıldız gösterilir).
class RatingStars extends StatelessWidget {
  /// [rating] (0–5) yıldızı.
  const RatingStars({required this.rating, this.size = 16, super.key});

  /// Puan.
  final double rating;

  /// Yıldız boyu.
  final double size;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF5A623);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: color,
          ),
      ],
    );
  }
}

/// Kursun isimsiz değerlendirmeleri. En az bir dersini bitiren yazabilir.
class CourseReviewsPage extends ConsumerWidget {
  /// [progress] kursunun değerlendirmeleri.
  const CourseReviewsPage({required this.progress, super.key});

  /// Kurs ve kullanıcının ilerlemesi.
  final CourseProgress progress;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CourseReview r,
  ) async {
    final ok = await confirm(
      context,
      title: 'Değerlendirme silinsin mi?',
      message: r.body.isEmpty ? '${r.rating} yıldız' : r.body,
      action: 'Sil',
    );
    if (!ok) return;
    final result = await ref.read(courseRepositoryProvider).deleteReview(r.id);
    if (result case Err(:final error) when context.mounted) {
      context.showMessage(error.message);
    }
    ref
      ..invalidate(courseReviewsProvider(progress.course.id))
      ..invalidate(courseRatingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final course = progress.course;
    final reviews = ref.watch(courseReviewsProvider(course.id));
    final mine = switch (reviews) {
      AsyncData(value: Ok(:final value)) =>
        value.where((r) => r.mine).firstOrNull,
      _ => null,
    };
    final admin = switch (ref.watch(courseAdminProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => false,
    };
    final canWrite = progress.done > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Değerlendirmeler')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (!await ensureCourseConsent(context, ref) ||
                    !context.mounted) {
                  return;
                }
                await context.push(
                  ReviewFormPage(courseId: course.id, review: mine),
                );
              },
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(
                mine == null ? 'Değerlendir' : 'Değerlendirmeni düzenle',
              ),
            )
          : null,
      body: ResultListView<CourseReview>(
        value: reviews,
        onRefresh: () async {
          ref
            ..invalidate(courseReviewsProvider(course.id))
            ..invalidate(courseRatingsProvider);
          await ref.read(courseReviewsProvider(course.id).future);
        },
        emptyIcon: Icons.reviews_outlined,
        emptyText: canWrite
            ? 'Henüz değerlendirme yok. İlk değerlendiren sen ol.'
            : 'Henüz değerlendirme yok. Bir dersini bitirince sen de '
                  'değerlendirebilirsin.',
        header: (list) {
          final average =
              list.fold<int>(0, (s, r) => s + r.rating) / list.length;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  average.toStringAsFixed(1),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RatingStars(rating: average, size: 22),
                      Text(
                        '${list.length} değerlendirme · isimler gösterilmez',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        itemBuilder: (context, r) => ListTile(
          title: Row(
            children: [
              RatingStars(rating: r.rating.toDouble()),
              const SizedBox(width: 8),
              Text(
                r.mine ? 'Senin değerlendirmen' : 'Bir öğrenci',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(r.body, style: theme.textTheme.bodyMedium),
                ),
              Text(
                formatDateTime(r.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: r.mine || admin
              ? IconButton(
                  tooltip: 'Değerlendirmeyi sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref, r),
                )
              : IconButton(
                  tooltip: 'Değerlendirmeyi şikayet et',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => context.push(ReportPage(reviewId: r.id)),
                ),
        ),
      ),
    );
  }
}

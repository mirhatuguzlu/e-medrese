import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/announcements/announcements_page.dart';
import 'package:e_medrese/presentation/features/courses/icazet_requests_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_discussion_page.dart';
import 'package:e_medrese/presentation/features/courses/medrese_courses_page.dart';
import 'package:e_medrese/presentation/features/posts/post_page.dart';
import 'package:e_medrese/presentation/features/rewards/reward_requests_page.dart';
import 'package:e_medrese/presentation/features/rewards/rewards_page.dart';
import 'package:e_medrese/presentation/features/shell/main_shell.dart';
import 'package:e_medrese/presentation/features/tasks/chest_page.dart';
import 'package:e_medrese/presentation/features/tasks/score_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [n]'nin ilgili olduğu sayfayı açar: görevler için ana ekran, duyuru için
/// duyurular, yıldız için yıldız sayfası (gün geçtiyse puan geçmişi), yorum
/// için paylaşım.
Future<void> openNotification(
  BuildContext context,
  WidgetRef ref,
  AppNotification n,
) async {
  if (n.kind
      case 'task_started' ||
          'task_paused' ||
          'task_resumed' ||
          'task_finished' ||
          'reminder') {
    // Öğrencinin görev kartları ana ekranda.
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(mainTabProvider.notifier).state = MainTab.tasks;
    ref
      ..invalidate(taskProgramProvider)
      ..invalidate(periodEntriesProvider);
    return;
  }

  final medrese = switch (await ref.read(myMedresesProvider.future)) {
    Ok(:final value) => value.where((m) => m.id == n.medreseId).firstOrNull,
    Err() => null,
  };
  if (!context.mounted || medrese == null) return;

  switch (n.kind) {
    case 'announcement':
      await context.push(AnnouncementsPage(medrese: medrese));
    case 'period_ready':
      final today = ref.read(todayProvider);
      // Yıldız yalnız dönemin bittiği günün ertesi açılır.
      await context.push(
        dateOnly(n.createdAt) == today
            ? ChestPage(
                medrese: medrese,
                periodStart: today.subtract(const Duration(days: 7)),
              )
            : ScoreHistoryPage(medrese: medrese),
      );
    case 'reward' || 'reward_rejected':
      await context.push(RewardsPage(medrese: medrese));
    case 'course_assigned':
      ref.invalidate(assignmentsProvider);
      await context.push(MedreseCoursesPage(medrese: medrese));
    case 'icazet_request':
      ref.invalidate(icazetRequestsProvider);
      await context.push(IcazetRequestsPage(medrese: medrese));
    case 'lesson_comment' when n.lessonId != null:
      final lesson = switch (await ref.read(coursesProvider.future)) {
        Ok(:final value) =>
          value
              .expand((c) => c.lessons)
              .where((l) => l.id == n.lessonId)
              .firstOrNull,
        Err() => null,
      };
      if (!context.mounted) return;
      await context.push(
        lesson == null
            ? MedreseCoursesPage(medrese: medrese)
            : LessonDiscussionPage(medrese: medrese, lesson: lesson),
      );
    case 'icazet_approved' || 'icazet_rejected' || 'lesson_comment':
      ref.invalidate(icazetRequestsProvider);
      await context.push(MedreseCoursesPage(medrese: medrese));
    case 'reward_request':
      await context.push(RewardRequestsPage(medrese: medrese));
    case 'comment' when n.postId != null:
      final post = await ref.read(feedRepositoryProvider).post(n.postId!);
      if (!context.mounted) return;
      switch (post) {
        case Ok(:final value?):
          await context.push(PostPage(medrese: medrese, post: value));
        case Ok():
          context.showMessage('Bu paylaşım silinmiş.');
        case Err(:final error):
          context.showMessage(error.message);
      }
  }
}

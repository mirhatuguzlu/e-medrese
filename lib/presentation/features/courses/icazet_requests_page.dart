import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/icazet_decision_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medresenin hocalarına gelen icazet istekleri: bekleyenler başta.
class IcazetRequestsPage extends ConsumerWidget {
  /// [medrese]'ye gelen istekler.
  const IcazetRequestsPage({required this.medrese, super.key});

  /// Medrese (kullanıcı kurucu ya da hoca).
  final Medrese medrese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = switch (ref.watch(coursesProvider)) {
      AsyncData(value: Ok(:final value)) => {
        for (final c in value) c.id: c.title,
      },
      _ => const <String, String>{},
    };
    final requests = ref.watch(icazetRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İcazet istekleri')),
      body: ResultListView<IcazetRequest>(
        value: switch (requests) {
          AsyncData(value: Ok(:final value)) => AsyncData(
            Ok([
              for (final pending in [true, false])
                ...value.where(
                  (r) =>
                      r.medreseId == medrese.id &&
                      (r.status == IcazetStatus.pending) == pending,
                ),
            ]),
          ),
          _ => requests,
        },
        onRefresh: () async {
          ref.invalidate(icazetRequestsProvider);
          await ref.read(icazetRequestsProvider.future);
        },
        emptyIcon: Icons.workspace_premium_outlined,
        emptyText:
            'Henüz icazet isteği yok. Verdiğin kursu bitiren öğrenciler '
            'buradan icazet ister.',
        itemBuilder: (context, r) {
          final course = titles[r.courseId] ?? 'Kurs yayından kalktı';
          return ListTile(
            leading: MemberPhoto(
              medreseId: r.medreseId,
              userId: r.userId,
              name: r.studentName,
            ),
            title: Text(displayName(r.studentName)),
            subtitle: Text(
              [
                course,
                switch (r.status) {
                  IcazetStatus.pending =>
                    'bekliyor · ${formatDateTime(r.createdAt)}',
                  IcazetStatus.approved =>
                    'onaylandı · ${displayName(r.decidedByName)}',
                  IcazetStatus.rejected =>
                    'geri çevrildi · ${displayName(r.decidedByName)}',
                },
              ].join(' · '),
            ),
            trailing: Icon(switch (r.status) {
              IcazetStatus.pending => Icons.chevron_right,
              IcazetStatus.approved => Icons.verified,
              IcazetStatus.rejected => Icons.block,
            }),
            onTap: r.status == IcazetStatus.pending
                ? () => context.push(
                    IcazetDecisionPage(request: r, courseTitle: course),
                  )
                : null,
          );
        },
      ),
    );
  }
}

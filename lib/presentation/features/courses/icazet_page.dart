import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/certificate_page.dart';
import 'package:e_medrese/presentation/features/courses/course_consent_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kullanıcının üyesi olduğu ve hocanın [courseId] kursunu verdiği
/// medreseler; [studentOnly] ise yalnız öğrencisi olduklarını (icazet).
List<Medrese> assignedMedreses(
  WidgetRef ref,
  String courseId, {
  bool studentOnly = false,
}) {
  final medreses = switch (ref.watch(myMedresesProvider)) {
    AsyncData(value: Ok(:final value)) => value,
    _ => const <Medrese>[],
  };
  final assigned = switch (ref.watch(assignmentsProvider)) {
    AsyncData(value: Ok(:final value)) => {
      for (final a in value)
        if (a.courseId == courseId) a.medreseId,
    },
    _ => const <String>{},
  };
  return [
    for (final m in medreses)
      if ((!studentOnly || m.myRole == MemberRole.student) &&
          assigned.contains(m.id))
        m,
  ];
}

/// Kullanıcının [courseId] kursundaki icazet isteği; yoksa `null`.
IcazetRequest? myIcazet(WidgetRef ref, String medreseId, String courseId) =>
    switch (ref.watch(icazetRequestsProvider)) {
      AsyncData(value: Ok(:final value)) =>
        value
            .where(
              (r) =>
                  r.medreseId == medreseId &&
                  r.courseId == courseId &&
                  r.userId == ref.watch(sessionProvider).valueOrNull?.user.id,
            )
            .firstOrNull,
      _ => null,
    };

/// Hocanın verdiği kursu bitiren öğrencinin icazet istediği ve durumunu
/// gördüğü sayfa. İcazeti o medresenin hocası onaylar.
class IcazetPage extends ConsumerStatefulWidget {
  /// [progress] kursunun icazeti.
  const IcazetPage({required this.progress, super.key});

  /// Kurs ve ilerlemesi.
  final CourseProgress progress;

  @override
  ConsumerState<IcazetPage> createState() => _IcazetPageState();
}

class _IcazetPageState extends ConsumerState<IcazetPage> {
  String? _sending;

  Future<void> _request(Medrese medrese) async {
    if (!await ensureCourseConsent(context, ref) || !mounted) return;
    setState(() => _sending = medrese.id);
    final result = await ref
        .read(courseRepositoryProvider)
        .requestIcazet(
          medreseId: medrese.id,
          courseId: widget.progress.course.id,
        );
    if (!mounted) return;
    setState(() => _sending = null);
    switch (result) {
      case Ok():
        ref.invalidate(icazetRequestsProvider);
        context.showMessage('İcazet isteğin hocalarına gönderildi.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = widget.progress.course;
    final finished = widget.progress.finished;
    final medreses = assignedMedreses(ref, course.id, studentOnly: true);
    return Scaffold(
      appBar: AppBar(title: const Text('İcazet')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(icazetRequestsProvider);
          await ref.read(icazetRequestsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              course.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İcazeti, bu kursu sana veren hocan onaylar. Kursun bütün '
              'derslerini bitirince iste; hocan onaylayınca icazet belgen '
              'açılır.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (medreses.isEmpty)
              const Text(
                'Bu kurs sana bir medresede hocan tarafından verilmedi. '
                'Kursu bitirince tamamlama belgen olur; icazet için hocanın '
                'kursu medresene vermesi gerekir.',
                textAlign: TextAlign.center,
              ),
            for (final m in medreses)
              _MedreseIcazet(
                medrese: m,
                progress: widget.progress,
                request: myIcazet(ref, m.id, course.id),
                finished: finished,
                sending: _sending == m.id,
                onRequest: () => _request(m),
              ),
          ],
        ),
      ),
    );
  }
}

class _MedreseIcazet extends StatelessWidget {
  const _MedreseIcazet({
    required this.medrese,
    required this.progress,
    required this.request,
    required this.finished,
    required this.sending,
    required this.onRequest,
  });

  final Medrese medrese;
  final CourseProgress progress;
  final IcazetRequest? request;
  final bool finished;
  final bool sending;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final button = FilledButton.icon(
      onPressed: finished && !sending ? onRequest : null,
      icon: const Icon(Icons.send_outlined),
      label: Text(
        r?.status == IcazetStatus.rejected ? 'Yeniden iste' : 'İcazet iste',
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(medrese.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...switch (r?.status) {
              null => [
                Text(
                  finished
                      ? 'Kursu bitirdin. Hocandan icazet isteyebilirsin.'
                      : 'İcazet istemek için kursun bütün derslerini bitir '
                            '(${progress.done}/${progress.course.lessons.length}).',
                ),
                const SizedBox(height: 12),
                button,
              ],
              IcazetStatus.pending => [
                Row(
                  children: [
                    Icon(Icons.hourglass_top, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hocanın onayını bekliyor · '
                        '${formatDateTime(r!.createdAt)}',
                      ),
                    ),
                  ],
                ),
              ],
              IcazetStatus.approved => [
                Text(
                  [
                    if (r!.decidedByName.isNotEmpty)
                      '${displayName(r.decidedByName)} onayladı',
                    if (r.decidedAt != null) formatDateTime(r.decidedAt!),
                  ].join(' · '),
                ),
                if (r.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('"${r.note}"', style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.push(
                    CertificatePage(
                      progress: progress,
                      icazet: r,
                      medreseName: medrese.name,
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('İcazetini gör'),
                ),
              ],
              IcazetStatus.rejected => [
                const Text('Hocan bu isteği geri çevirdi.'),
                if (r!.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hocanın notu: ${r.note}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                button,
              ],
            },
          ],
        ),
      ),
    );
  }
}

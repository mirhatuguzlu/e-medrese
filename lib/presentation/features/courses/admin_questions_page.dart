import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/presentation/features/courses/question_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir dersin tekrar sorularını yönetme (uygulama yöneticileri).
class AdminQuestionsPage extends ConsumerWidget {
  /// [courseId] kursunun [lessonId] dersinin soruları.
  const AdminQuestionsPage({
    required this.courseId,
    required this.lessonId,
    super.key,
  });

  /// Kurs.
  final String courseId;

  /// Ders.
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = switch (ref.watch(adminCoursesProvider)) {
      AsyncData(value: Ok(:final value)) =>
        value
            .where((c) => c.id == courseId)
            .firstOrNull
            ?.lessons
            .where((l) => l.id == lessonId)
            .firstOrNull,
      _ => null,
    };
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ders bulunamadı.')),
      );
    }
    final theme = Theme.of(context);
    final questions = lesson.questions;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          QuestionFormPage(
            lessonId: lesson.id,
            position: (questions.lastOrNull?.position ?? 0) + 1,
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Soru ekle'),
      ),
      body: questions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Bu derste tekrar sorusu yok. Öğrenciler dersi bitirince '
                  'çözsün diye çoktan seçmeli soru ekle.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: questions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final q = questions[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(q.question),
                  subtitle: Text(
                    'Doğru: ${q.options[q.answer]}',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () => context.push(
                    QuestionFormPage(
                      lessonId: lesson.id,
                      position: q.position,
                      question: q,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

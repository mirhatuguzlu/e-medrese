import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/online_medrese_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kurs arama: başlık, hoca, açıklama, kategori ve ders adlarında; seviyeye
/// göre süzülür.
class CourseSearchPage extends ConsumerStatefulWidget {
  /// Arama sayfası.
  const CourseSearchPage({super.key});

  @override
  ConsumerState<CourseSearchPage> createState() => _CourseSearchPageState();
}

class _CourseSearchPageState extends ConsumerState<CourseSearchPage> {
  final _query = TextEditingController();
  CourseLevel? _level;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = switch (ref.watch(coursesProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <Course>[],
    };
    final progress = switch (ref.watch(lessonProgressProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String, LessonProgress>{},
    };
    final text = _query.text.trim();
    final results = [
      for (final c in courses)
        if ((_level == null || c.level == _level) && courseMatches(c, text)) c,
    ];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Kurs, hoca ya da konu ara',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (text.isNotEmpty)
            IconButton(
              tooltip: 'Temizle',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_query.clear),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final l in <CourseLevel?>[null, ...CourseLevel.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l?.label ?? 'Her seviye'),
                      selected: l == _level,
                      onSelected: (_) => setState(() => _level = l),
                    ),
                  ),
              ],
            ),
          ),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aradığın kurs bulunamadı. Başka bir kelime dene.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final c in results)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: CourseCard(progress: CourseProgress(c, progress)),
            ),
        ],
      ),
    );
  }
}

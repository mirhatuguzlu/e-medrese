import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/online_medrese_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Lesson _lesson(int i, {String section = '', int duration = 600}) => Lesson(
  id: 'l$i',
  position: i,
  section: section,
  title: 'Ders başlığı $i',
  description: '',
  youtubeId: 'abcdefghij$i',
  durationSeconds: duration,
);

final _course = Course(
  id: 'c1',
  title: 'Temel Akaid',
  subtitle: 'İmanın esasları',
  description: 'Uzun açıklama',
  teacher: 'Hoca Efendi',
  category: CourseCategory.akaid,
  coverUrl: '',
  lessons: [_lesson(1, section: 'Giriş'), _lesson(2), _lesson(3)],
);

LessonProgress _p(
  String id, {
  required int day,
  int watched = 100,
  bool done = false,
}) => LessonProgress(
  lessonId: id,
  positionSeconds: watched,
  watchedSeconds: watched,
  updatedAt: DateTime(2026, 11, day),
  completedAt: done ? DateTime(2026, 11, day) : null,
);

void main() {
  group('ileri sarma kilidi', () {
    test('ilk izleyişte izlenen yerden öteye gidilemez, geri serbest', () {
      expect(allowedSeek(target: 300, watched: 120, completed: false), 120);
      expect(allowedSeek(target: 60, watched: 120, completed: false), 60);
      expect(allowedSeek(target: -5, watched: 120, completed: false), 0);
    });

    test('ders bitince her yere sarılır', () {
      expect(allowedSeek(target: 300, watched: 120, completed: true), 300);
    });

    test('%90 izlenince tamamlanır; süre bilinmiyorsa tamamlanmaz', () {
      expect(isWatched(539, 600), isFalse);
      expect(isWatched(540, 600), isTrue);
      expect(isWatched(1000, 0), isFalse);
    });
  });

  group('kurs ilerlemesi', () {
    test('hiç başlanmadıysa ilk ders', () {
      final p = CourseProgress(_course, const {});
      expect(p.started, isFalse);
      expect(p.next?.id, 'l1');
      expect(p.done, 0);
    });

    test('son izlenen yarım kaldıysa o ders', () {
      final p = CourseProgress(_course, {
        'l1': _p('l1', day: 1, done: true),
        'l2': _p('l2', day: 2),
      });
      expect(p.next?.id, 'l2');
      expect(p.done, 1);
      expect(p.fraction, closeTo(1 / 3, 1e-9));
      expect(p.lastWatched, DateTime(2026, 11, 2));
    });

    test('son izlenen bittiyse ondan sonraki tamamlanmamış ders', () {
      final p = CourseProgress(_course, {
        'l1': _p('l1', day: 1),
        'l2': _p('l2', day: 3, done: true),
      });
      expect(p.next?.id, 'l3');
    });

    test('sonrası bittiyse baştaki yarım ders; hepsi bittiyse ilk ders', () {
      expect(
        CourseProgress(_course, {
          'l1': _p('l1', day: 1),
          'l3': _p('l3', day: 3, done: true),
        }).next?.id,
        'l1',
      );
      final all = CourseProgress(_course, {
        for (final l in _course.lessons) l.id: _p(l.id, day: 1, done: true),
      });
      expect(all.finished, isTrue);
      expect(all.next?.id, 'l1');
    });
  });

  test('satırdan kurs: dersler sırayla, kapak yoksa ilk dersin kapağı', () {
    final c = Course.fromJson({
      'id': 'c',
      'title': 'T',
      'category': 'fikih',
      'lessons': [
        {'id': 'b', 'position': 2, 'title': 'B', 'youtube_id': 'bbbbbbbbbbb'},
        {'id': 'a', 'position': 1, 'title': 'A', 'youtube_id': 'aaaaaaaaaaa'},
      ],
    });
    expect(c.lessons.map((l) => l.id), ['a', 'b']);
    expect(c.cover, 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg');
    expect(c.category, CourseCategory.fikih);
  });

  test('süre biçimleri', () {
    expect(formatLength(30), '1 dk');
    expect(formatLength(12 * 60), '12 dk');
    expect(formatLength(80 * 60), '1 sa 20 dk');
    expect(formatLength(120 * 60), '2 sa');
    expect(formatClock(187), '3:07');
    expect(formatClock(3787), '1:03:07');
  });

  group('sayfalar', () {
    late FakeCourseRepository repo;

    setUp(() => repo = FakeCourseRepository()..courseList.add(_course));

    Future<void> pump(WidgetTester tester) async {
      // Uzun ekran: kartlar ve ders listesi kaydırmadan görünsün.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => Stream.value(testSession)),
            ...pushOverrides(courses: repo),
          ],
          child: const MaterialApp(home: OnlineMedresePage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('katalogda kurs kartı; başlanmadıysa devam kartı yok', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Temel Akaid'), findsOneWidget);
      expect(find.text('Hoca Efendi'), findsOneWidget);
      expect(find.text('3 ders · 30 dk'), findsOneWidget);
      expect(find.text('Kaldığın yerden devam et'), findsNothing);
    });

    testWidgets('başlanan kurs için devam kartı ve ilerleme', (tester) async {
      repo.progressMap['l1'] = _p('l1', day: 1, done: true);
      await pump(tester);
      expect(find.text('Kaldığın yerden devam et'), findsOneWidget);
      expect(find.text('Ders 2 · Ders başlığı 2'), findsOneWidget);
      expect(find.text('1/3 ders'), findsWidgets);
    });

    testWidgets('kurs sayfası dersleri bölümüyle, düğme sıradaki ders', (
      tester,
    ) async {
      repo.progressMap['l1'] = _p('l1', day: 1, done: true);
      await pump(tester);
      // Devam kartında da kurs adı yazar; karta hoca adından dokunulur.
      await tester.tap(find.text('Hoca Efendi'));
      await tester.pumpAndSettle();
      expect(find.text('Devam et: Ders 2'), findsOneWidget);
      expect(find.text('%33'), findsOneWidget);
      expect(find.text('Ders 1 · 10 dk · Tamamlandı'), findsOneWidget);
      expect(find.text('Giriş'), findsOneWidget);
    });

    testWidgets('rıza yoksa derse başlamadan rıza sayfası açılır', (
      tester,
    ) async {
      repo.consent = false;
      await pump(tester);
      await tester.tap(find.text('Temel Akaid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kursa başla'));
      await tester.pumpAndSettle();
      expect(find.text('Online Medrese rızası'), findsOneWidget);
      // Rıza verilmeden dönülürse ders açılmaz.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Kursa başla'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });
  });
}

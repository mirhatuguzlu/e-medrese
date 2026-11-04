import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/course_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_note_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_notes_page.dart';
import 'package:e_medrese/presentation/features/courses/medrese_courses_page.dart';
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
  lessons: [
    _lesson(1, section: 'Giriş'),
    _lesson(2),
    _lesson(3),
  ],
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
  group('hocanın verdiği kurslar, notlar, icazet', _assignmentTests);

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

  test('YouTube linkinden video kimliği', () {
    const id = 'dQw4w9WgXcQ';
    for (final link in [
      id,
      'https://www.youtube.com/watch?v=$id&t=42s',
      'youtube.com/watch?feature=share&v=$id',
      'https://youtu.be/$id?si=abc',
      'https://m.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/live/$id',
    ]) {
      expect(parseYoutubeId(link), id, reason: link);
    }
    expect(parseYoutubeId('https://vimeo.com/12345678901'), isNull);
    expect(parseYoutubeId('https://youtube.com/watch?v=short'), isNull);
    expect(parseYoutubeId(''), isNull);
  });

  test('süre girişi', () {
    expect(parseDuration('12:34'), 754);
    expect(parseDuration('1:02:03'), 3723);
    expect(parseDuration('45'), 2700);
    expect(parseDuration('12:75'), isNull);
    expect(parseDuration('abc'), isNull);
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

    testWidgets('yönetim düğmesi yalnız yöneticiye görünür', (tester) async {
      await pump(tester);
      expect(find.byTooltip('Kurs yönetimi'), findsNothing);
    });

    testWidgets("yönetici linkle ders ekler; başlık YouTube'dan gelir", (
      tester,
    ) async {
      repo
        ..admin = true
        ..title = 'YouTube başlığı';
      await pump(tester);
      await tester.tap(find.byTooltip('Kurs yönetimi'));
      await tester.pumpAndSettle();
      expect(find.text('Yayında · 3 ders · Akaid'), findsOneWidget);
      await tester.tap(find.text('Temel Akaid'));
      await tester.pumpAndSettle();
      expect(find.text('1. Ders başlığı 1'), findsOneWidget);
      await tester.tap(find.text('Ders ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'YouTube linki'),
        'https://youtu.be/dQw4w9WgXcQ',
      );
      await tester.pumpAndSettle();
      expect(find.text('YouTube başlığı'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Süre'),
        '12:34',
      );
      await tester.tap(find.text('Dersi ekle'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['lesson null c1 4 YouTube başlığı dQw4w9WgXcQ 754']);
    });

    testWidgets('geçersiz linkle ders eklenmez', (tester) async {
      repo.admin = true;
      await pump(tester);
      await tester.tap(find.byTooltip('Kurs yönetimi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temel Akaid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ders ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'YouTube linki'),
        'https://vimeo.com/1',
      );
      await tester.tap(find.text('Dersi ekle'));
      await tester.pumpAndSettle();
      expect(
        find.text('Geçerli bir YouTube video linki yapıştır.'),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);
    });

    testWidgets('yeni kurs taslak açılır, ders sayfasına geçilir', (
      tester,
    ) async {
      repo.admin = true;
      await pump(tester);
      await tester.tap(find.byTooltip('Kurs yönetimi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni kurs'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kurs adı'),
        'Siyer-i Nebi',
      );
      await tester.tap(find.text('Kategori'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siyer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kursu aç'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['course null Siyer-i Nebi siyer false']);
      expect(find.text('Taslak'), findsOneWidget);
      expect(
        find.text('Henüz ders yok. YouTube linkiyle ilk dersi ekle.'),
        findsOneWidget,
      );
    });
  });
}

void _assignmentTests() {
  const medrese = Medrese(
    id: 'm1',
    name: 'Nur Medresesi',
    description: '',
    inviteCode: 'ABC',
    myRole: MemberRole.teacher,
  );

  late FakeCourseRepository repo;

  setUp(() => repo = FakeCourseRepository()..courseList.add(_course));

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          ...pushOverrides(courses: repo),
        ],
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hocanın verdiği kurs akışta etiketli ve en üstte', (
    tester,
  ) async {
    repo
      ..courseList.insert(
        0,
        const Course(
          id: 'c0',
          title: 'Fıkıh Usulü',
          subtitle: '',
          description: '',
          teacher: '',
          category: CourseCategory.fikih,
          coverUrl: '',
          lessons: [],
        ),
      )
      ..assignmentList.add(
        CourseAssignment(
          medreseId: 'm1',
          medreseName: 'Nur Medresesi',
          courseId: 'c1',
          createdAt: DateTime(2026, 11, 7),
          dueOn: DateTime(2026, 11, 20),
        ),
      );
    await pump(tester, const OnlineMedresePage());
    expect(find.text('Hocan verdi · son gün 20.11'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Temel Akaid')).dy,
      lessThan(tester.getTopLeft(find.text('Fıkıh Usulü')).dy),
    );
  });

  testWidgets('hoca kurs verir; verilmiş kurs listede çıkmaz', (tester) async {
    await pump(tester, const MedreseCoursesPage(medrese: medrese));
    expect(find.textContaining('Henüz kurs vermedin'), findsOneWidget);
    await tester.tap(find.text('Kurs ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temel Akaid'));
    await tester.tap(find.text('Kursu ver'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['assign m1 c1 null']);
  });

  testWidgets('hoca öğrenci ilerlemesini görür; rızasız öğrenci gizli', (
    tester,
  ) async {
    repo
      ..assignmentList.add(
        CourseAssignment(
          medreseId: 'm1',
          medreseName: 'Nur Medresesi',
          courseId: 'c1',
          createdAt: DateTime(2026, 11, 7),
        ),
      )
      ..studentProgress.addAll([
        StudentCourseProgress(
          userId: 'u1',
          name: 'Ahmet',
          consent: true,
          done: 1,
          lastWatched: DateTime(2026, 11, 7, 10),
        ),
        const StudentCourseProgress(
          userId: 'u2',
          name: 'Mehmet',
          consent: false,
          done: 0,
        ),
      ]);
    await pump(tester, const MedreseCoursesPage(medrese: medrese));
    await tester.tap(find.text('Temel Akaid'));
    await tester.pumpAndSettle();
    expect(find.text('1/3 ders · son izleme 07.11.2026 10:00'), findsOneWidget);
    expect(find.text('İlerlemesini paylaşmaya rıza vermedi.'), findsOneWidget);
    await tester.tap(find.byTooltip('Kursu geri al'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['unassign m1 c1']);
  });

  testWidgets('kurs bitince tamamlama belgesi', (tester) async {
    for (final l in _course.lessons) {
      repo.progressMap[l.id] = _p(l.id, day: 6, done: true);
    }
    await pump(tester, const CoursePage(courseId: 'c1'));
    await tester.tap(find.text('Kursu bitirdin'));
    await tester.pumpAndSettle();
    expect(find.text('TAMAMLAMA BELGESİ'), findsOneWidget);
    expect(find.text('Temel Akaid'), findsOneWidget);
    expect(find.text('06.11.2026'), findsOneWidget);
  });

  testWidgets('derse not yazılır', (tester) async {
    await pump(tester, const LessonNotePage(lessonId: 'l1', seconds: 187));
    expect(find.text('Not · 3:07'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Güzel bir örnek');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['note l1 187 Güzel bir örnek']);
  });

  testWidgets('nota dokununca o saniyeyle dönülür', (tester) async {
    repo.noteList.add(
      LessonNote(
        id: 'n1',
        lessonId: 'l1',
        seconds: 65,
        body: 'Önemli yer',
        createdAt: DateTime(2026, 11, 7),
      ),
    );
    int? returned;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              returned = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) =>
                      LessonNotesPage(lesson: _course.lessons.first),
                ),
              ),
          child: const Text('aç'),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('1:05'), findsOneWidget);
    await tester.tap(find.text('Önemli yer'));
    await tester.pumpAndSettle();
    expect(returned, 65);
  });
}

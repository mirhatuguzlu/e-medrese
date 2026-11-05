import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/presentation/features/courses/admin_resources_page.dart';
import 'package:e_medrese/presentation/features/courses/course_discussions_page.dart';
import 'package:e_medrese/presentation/features/courses/course_form_page.dart';
import 'package:e_medrese/presentation/features/courses/course_page.dart';
import 'package:e_medrese/presentation/features/courses/course_search_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_discussion_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_quiz_page.dart';
import 'package:e_medrese/presentation/features/courses/medrese_courses_page.dart';
import 'package:e_medrese/presentation/features/courses/my_courses_page.dart';
import 'package:e_medrese/presentation/features/courses/question_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _q1 = LessonQuestion(
  id: 'q1',
  lessonId: 'l1',
  position: 1,
  question: 'İmanın şartı kaçtır?',
  options: ['Beş', 'Altı', 'Yedi'],
  answer: 1,
  explanation: 'Amentü altı esastır.',
);

const _q2 = LessonQuestion(
  id: 'q2',
  lessonId: 'l1',
  position: 2,
  question: 'Kelime-i şehadet kaç kelimedir?',
  options: ['İki', 'Üç'],
  answer: 0,
  explanation: '',
);

Lesson _lesson(int i, {List<LessonQuestion> questions = const []}) => Lesson(
  id: 'l$i',
  position: i,
  section: '',
  title: 'Ders $i başlığı',
  description: '',
  youtubeId: 'abcdefghij$i',
  durationSeconds: 600,
  questions: questions,
);

final _course = Course(
  id: 'c1',
  title: 'Temel Akaid',
  subtitle: 'İmanın esasları',
  description: '',
  teacher: 'Hoca Efendi',
  category: CourseCategory.akaid,
  coverUrl: '',
  level: CourseLevel.baslangic,
  outcomes: 'Amentüyü açıklarsın\n\n  Şirki tanırsın  ',
  lessons: [
    _lesson(1, questions: const [_q1, _q2]),
    _lesson(2),
  ],
);

final _siyer = Course(
  id: 'c2',
  title: 'Siyer-i Nebi',
  subtitle: '',
  description: '',
  teacher: '',
  category: CourseCategory.siyer,
  coverUrl: '',
  level: CourseLevel.ileri,
  lessons: [_lesson(3)],
);

LessonProgress _done(String id, {int day = 6}) => LessonProgress(
  lessonId: id,
  positionSeconds: 600,
  watchedSeconds: 600,
  updatedAt: DateTime(2026, 11, day),
  completedAt: DateTime(2026, 11, day),
);

Medrese _medrese(MemberRole role) => Medrese(
  id: 'm1',
  name: 'Nur Medresesi',
  description: '',
  inviteCode: 'ABC',
  myRole: role,
);

CourseAssignment _assignment() => CourseAssignment(
  medreseId: 'm1',
  medreseName: 'Nur Medresesi',
  courseId: 'c1',
  createdAt: DateTime(2026, 11),
);

void main() {
  group('alan', () {
    test('arama: Türkçe harf ve şapka farkı gözetmez, ders adları da', () {
      expect(courseMatches(_course, 'akaid'), isTrue);
      expect(courseMatches(_course, 'İMAN esas'), isTrue);
      expect(courseMatches(_course, 'iman'), isTrue);
      expect(courseMatches(_course, 'hoca efendi'), isTrue);
      expect(courseMatches(_course, 'ders 2'), isTrue);
      expect(courseMatches(_course, 'akaid fıkıh'), isFalse);
      expect(courseMatches(_siyer, '  '), isTrue);
      expect(courseMatches(_siyer, 'SİYER'), isTrue);
    });

    test('Türkçe büyük harf', () {
      expect(upperTr('Siyer · İleri'), 'SİYER · İLERİ');
      expect(upperTr('Fıkıh'), 'FIKIH');
    });

    test('satırdan kurs: seviye, kazanımlar, sıralı sorular', () {
      final c = Course.fromJson({
        'id': 'c',
        'title': 'K',
        'category': 'fikih',
        'level': 'orta',
        'outcomes': 'Bir\n\nİki ',
        'lessons': [
          {
            'id': 'l',
            'position': 1,
            'title': 'D',
            'youtube_id': 'abcdefghijk',
            'lesson_questions': [
              {
                'id': 'b',
                'lesson_id': 'l',
                'position': 2,
                'question': 'S2',
                'options': ['x', 'y'],
                'answer': 1,
              },
              {
                'id': 'a',
                'lesson_id': 'l',
                'position': 1,
                'question': 'S1',
                'options': ['x', 'y', 'z'],
                'answer': 2,
                'explanation': 'çünkü',
              },
            ],
          },
        ],
      });
      expect(c.level, CourseLevel.orta);
      expect(c.outcomeList, ['Bir', 'İki']);
      expect(c.lessons.single.questions.map((q) => q.id), ['a', 'b']);
      expect(c.questionCount, 2);
      // Bilinmeyen seviye çökertmez.
      expect(
        Course.fromJson({
          'id': 'c',
          'title': 'K',
          'category': 'fikih',
          'level': 'uzman',
        }).level,
        isNull,
      );
    });

    test('kurs görevi öğrencinin hedef planına girmez', () {
      final kurs = testTasks.singleWhere((t) => t.id == 'kurs');
      expect(kurs.selfMarked, isFalse);
      expect(kurs.maxScore, 50);
      final plan = planGoal(
        tasks: testTasks,
        total: 0,
        threshold: 1000,
        weeks: 4,
      );
      expect(plan.needs.map((n) => n.task.id), isNot(contains('kurs')));
    });
  });

  group('sayfalar', () {
    late FakeCourseRepository repo;
    late FakeMedreseRepository medreses;
    late FakeLegacySavedCourses legacy;

    setUp(() {
      repo = FakeCourseRepository()..courseList.addAll([_course, _siyer]);
      medreses = FakeMedreseRepository();
      legacy = FakeLegacySavedCourses();
    });

    Future<void> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => Stream.value(testSession)),
            medreseRepositoryProvider.overrideWithValue(medreses),
            ...pushOverrides(courses: repo, legacy: legacy),
          ],
          child: MaterialApp(home: page),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tekrar soruları: yanlışta doğrusu ve açıklama, sonuç', (
      tester,
    ) async {
      // İkinci soru daha önce cevaplanmış: yeniden kaydedilmez.
      repo.questionResultMap['q2'] = true;
      await pump(tester, LessonQuizPage(lesson: _course.lessons.first));
      expect(find.text('Soru 1 / 2'), findsOneWidget);
      // Şık seçilmeden kontrol edilemez.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kontrol et'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Beş'));
      await tester.pump();
      await tester.tap(find.text('Kontrol et'));
      await tester.pumpAndSettle();
      expect(find.text('Doğru cevap: B'), findsOneWidget);
      expect(find.text('Amentü altı esastır.'), findsOneWidget);
      expect(repo.calls, ['answer q1 0']);

      await tester.tap(find.text('Sonraki soru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İki'));
      await tester.pump();
      await tester.tap(find.text('Kontrol et'));
      await tester.pumpAndSettle();
      expect(find.text('Doğru!'), findsOneWidget);
      expect(repo.calls, ['answer q1 0']);

      await tester.tap(find.text('Sonucu gör'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2 doğru'), findsOneWidget);
      await tester.tap(find.text('Yeniden çöz'));
      await tester.pumpAndSettle();
      expect(find.text('Soru 1 / 2'), findsOneWidget);
    });

    testWidgets('yönetici şık ekleyip doğru şıkkı seçerek soru ekler', (
      tester,
    ) async {
      await pump(tester, const QuestionFormPage(lessonId: 'l2', position: 1));
      await tester.tap(find.text('Soruyu ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Soruyu yaz.'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Soru'),
        'Hangisi farzdır?',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'A şıkkı'),
        'Sünnet',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'B şıkkı'),
        'Vacip',
      );
      await tester.tap(find.text('Şık ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'C şıkkı'),
        'Namaz',
      );
      await tester.tap(find.byType(Radio<int>).at(2));
      await tester.tap(find.text('Soruyu ekle'));
      await tester.pumpAndSettle();
      expect(repo.calls, [
        'question null l2 1 Hangisi farzdır? Sünnet|Vacip|Namaz 2 ',
      ]);
    });

    testWidgets('ders tartışmasına videonun anıyla yazılır; o ana dönülür', (
      tester,
    ) async {
      medreses.memberList.add(
        Member(
          userId: 'u2',
          name: 'Hoca Ali',
          role: MemberRole.teacher,
          joinedAt: DateTime(2026),
        ),
      );
      repo.commentList.add(
        LessonComment(
          id: 'k1',
          lessonId: 'l1',
          authorId: 'u2',
          authorName: 'Hoca Ali',
          body: 'Bu kısma dikkat edin.',
          createdAt: DateTime(2026, 11, 7, 9),
          seconds: 65,
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
                    builder: (_) => LessonDiscussionPage(
                      medrese: _medrese(MemberRole.student),
                      lesson: _course.lessons.first,
                      seconds: 187,
                    ),
                  ),
                ),
            child: const Text('aç'),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Hoca'), findsOneWidget);
      expect(find.text('Videonun 3:07 anına bağla'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Burayı anlamadım');
      await tester.tap(find.byTooltip('Gönder'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['comment m1 l1 187 Burayı anlamadım']);

      // Hocanın yazısı şikayet edilebilir.
      await tester.tap(find.byTooltip('Yazıyı şikayet et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam ya da reklam'));
      await tester.tap(find.text('Gönder'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'report k1 null spam');

      await tester.tap(find.text('1:05'));
      await tester.pumpAndSettle();
      expect(returned, 65);
    });

    testWidgets('hoca kursun son tartışmalarını görür', (tester) async {
      repo.commentList.add(
        LessonComment(
          id: 'k1',
          lessonId: 'l2',
          authorId: 'u3',
          authorName: 'Ayşe',
          body: 'Soru: abdest?',
          createdAt: DateTime(2026, 11, 7, 9),
        ),
      );
      await pump(
        tester,
        CourseDiscussionsPage(
          medrese: _medrese(MemberRole.teacher),
          course: _course,
        ),
      );
      expect(find.text('Soru: abdest?'), findsOneWidget);
      expect(find.text('Ders 2 · 07.11.2026 09:00'), findsOneWidget);
      await tester.tap(find.text('Soru: abdest?'));
      await tester.pumpAndSettle();
      expect(find.text('Ders tartışması'), findsOneWidget);
      // Oynatıcıdan açılmadı: anı bağlama seçeneği yok.
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('kurs sayfası: seviye, kazanımlar, puan; değerlendirme', (
      tester,
    ) async {
      repo
        ..progressMap['l1'] = _done('l1')
        ..ratingMap['c1'] = (average: 4.5, count: 2)
        ..reviewList.addAll([
          CourseReview(
            id: 'r1',
            rating: 5,
            body: 'Çok faydalı',
            createdAt: DateTime(2026, 11, 6),
            mine: false,
          ),
          CourseReview(
            id: 'r2',
            rating: 4,
            body: '',
            createdAt: DateTime(2026, 11, 5),
            mine: false,
          ),
        ]);
      await pump(tester, const CoursePage(courseId: 'c1'));
      expect(find.text('AKAİD · BAŞLANGIÇ'), findsOneWidget);
      expect(find.text('Amentüyü açıklarsın'), findsOneWidget);
      expect(find.text('Şirki tanırsın'), findsOneWidget);
      expect(find.text('2 değerlendirme'), findsOneWidget);
      expect(find.text('Ders 1 · 10 dk · 2 soru · Tamamlandı'), findsOneWidget);

      await tester.tap(find.text('2 değerlendirme'));
      await tester.pumpAndSettle();
      expect(find.text('Bir öğrenci'), findsNWidgets(2));
      expect(
        find.text('2 değerlendirme · isimler gösterilmez'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Değerlendirmeyi şikayet et').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hakaret ya da taciz'));
      await tester.tap(find.text('Gönder'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['report null r1 insult']);

      await tester.tap(find.text('Değerlendir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 yıldız'));
      await tester.pump();
      expect(find.text('Çok iyi'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Sade anlatım');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'review c1 4 Sade anlatım');
    });

    testWidgets('ders bitirmeyen değerlendiremez', (tester) async {
      await pump(tester, const CoursePage(courseId: 'c1'));
      expect(find.text('Henüz değerlendirme yok'), findsOneWidget);
      await tester.tap(find.text('Henüz değerlendirme yok'));
      await tester.pumpAndSettle();
      expect(find.text('Değerlendir'), findsNothing);
      expect(find.textContaining('Bir dersini bitirince'), findsOneWidget);
    });

    testWidgets('öğrenci bitirdiği verilen kurs için icazet ister', (
      tester,
    ) async {
      medreses.medreses.add(_medrese(MemberRole.student));
      repo.assignmentList.add(_assignment());
      for (final l in _course.lessons) {
        repo.progressMap[l.id] = _done(l.id);
      }
      await pump(tester, const CoursePage(courseId: 'c1'));
      expect(find.text('Hocandan icazet iste'), findsOneWidget);
      await tester.tap(find.text('İcazet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İcazet iste'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['icazet m1 c1']);
    });

    testWidgets('bitmemiş kursta icazet istenemez', (tester) async {
      medreses.medreses.add(_medrese(MemberRole.student));
      repo
        ..assignmentList.add(_assignment())
        ..progressMap['l1'] = _done('l1');
      await pump(tester, const CoursePage(courseId: 'c1'));
      await tester.tap(find.text('İcazet'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(1/2)'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('İcazet iste'),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('onaylanan icazet belgesinde hoca ve medrese yazar', (
      tester,
    ) async {
      medreses.medreses.add(_medrese(MemberRole.student));
      repo
        ..assignmentList.add(_assignment())
        ..icazetList.add(
          IcazetRequest(
            id: 'abcdef12-3456',
            medreseId: 'm1',
            courseId: 'c1',
            userId: 'u1',
            studentName: '',
            status: IcazetStatus.approved,
            note: 'Tebrikler',
            decidedByName: 'Hoca Ali',
            createdAt: DateTime(2026, 11, 6),
            decidedAt: DateTime(2026, 11, 7, 10),
          ),
        );
      for (final l in _course.lessons) {
        repo.progressMap[l.id] = _done(l.id);
      }
      await pump(tester, const CoursePage(courseId: 'c1'));
      expect(find.text('Hocan icazetini onayladı'), findsOneWidget);
      await tester.tap(find.text('İcazet'));
      await tester.pumpAndSettle();
      expect(find.text('"Tebrikler"'), findsOneWidget);
      await tester.tap(find.text('İcazetini gör'));
      await tester.pumpAndSettle();
      expect(find.text('İCAZET'), findsOneWidget);
      expect(find.text('Hoca Ali'), findsOneWidget);
      expect(find.text('Nur Medresesi'), findsOneWidget);
      expect(find.text('07.11.2026'), findsOneWidget);
      expect(find.textContaining('Belge no: ABCDEF12'), findsOneWidget);
    });

    testWidgets('geri çevrilen icazette hocanın notu, yeniden istenir', (
      tester,
    ) async {
      medreses.medreses.add(_medrese(MemberRole.student));
      repo
        ..assignmentList.add(_assignment())
        ..icazetList.add(
          IcazetRequest(
            id: 'r1',
            medreseId: 'm1',
            courseId: 'c1',
            userId: 'u1',
            studentName: '',
            status: IcazetStatus.rejected,
            note: 'Soruları tekrar çöz',
            decidedByName: 'Hoca Ali',
            createdAt: DateTime(2026, 11, 6),
          ),
        );
      for (final l in _course.lessons) {
        repo.progressMap[l.id] = _done(l.id);
      }
      await pump(tester, const CoursePage(courseId: 'c1'));
      await tester.tap(find.text('İcazet'));
      await tester.pumpAndSettle();
      expect(find.text('Hocanın notu: Soruları tekrar çöz'), findsOneWidget);
      await tester.tap(find.text('Yeniden iste'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['icazet m1 c1']);
    });

    testWidgets('hoca icazet isteğini notsuz geri çeviremez, onaylar', (
      tester,
    ) async {
      repo
        ..assignmentList.add(_assignment())
        ..icazetList.add(
          IcazetRequest(
            id: 'r1',
            medreseId: 'm1',
            courseId: 'c1',
            userId: 'u3',
            studentName: 'Ayşe',
            status: IcazetStatus.pending,
            note: '',
            decidedByName: '',
            createdAt: DateTime(2026, 11, 7, 9),
          ),
        );
      await pump(
        tester,
        MedreseCoursesPage(medrese: _medrese(MemberRole.teacher)),
      );
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byTooltip('İcazet istekleri'));
      await tester.pumpAndSettle();
      expect(
        find.text('Temel Akaid · bekliyor · 07.11.2026 09:00'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ayşe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geri çevir'));
      await tester.pumpAndSettle();
      expect(
        find.text('Geri çevirirken öğrencine nedenini yaz.'),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'Maşallah');
      await tester.tap(find.text('İcazeti onayla'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['decide r1 true Maşallah']);
    });

    testWidgets('arama metinle ve seviyeyle süzer', (tester) async {
      await pump(tester, const CourseSearchPage());
      expect(find.text('Temel Akaid'), findsOneWidget);
      expect(find.text('Siyer-i Nebi'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'siyer');
      await tester.pumpAndSettle();
      expect(find.text('Temel Akaid'), findsNothing);
      expect(find.text('Siyer-i Nebi'), findsOneWidget);
      await tester.tap(find.byTooltip('Temizle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Başlangıç'));
      await tester.pumpAndSettle();
      expect(find.text('Temel Akaid'), findsOneWidget);
      expect(find.text('Siyer-i Nebi'), findsNothing);
      await tester.enterText(find.byType(TextField), 'fıkıh');
      await tester.pumpAndSettle();
      expect(find.textContaining('bulunamadı'), findsOneWidget);
    });

    testWidgets('kurslarım: devam edenler ve bitenler', (tester) async {
      repo
        ..progressMap['l1'] = _done('l1')
        ..progressMap['l3'] = _done('l3', day: 7);
      await pump(tester, const MyCoursesPage());
      expect(find.text('Devam edenler'), findsOneWidget);
      expect(find.text('Bitirdiklerin'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Temel Akaid')).dy,
        lessThan(tester.getTopLeft(find.text('Siyer-i Nebi')).dy),
      );
      expect(find.text('20 dk'), findsOneWidget);
    });

    testWidgets('kurslarım boşsa yönlendirir', (tester) async {
      await pump(tester, const MyCoursesPage());
      expect(find.textContaining('Henüz bir kursa başlamadın'), findsOneWidget);
    });

    testWidgets('yönetici kursa seviye ve kazanım yazar', (tester) async {
      await pump(tester, const CourseFormPage());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kurs adı'),
        'Fıkıh Usulü',
      );
      await tester.tap(find.text('Kategori'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fıkıh').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belirtilmedi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orta').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Bu kursta öğrenecekleri (isteğe bağlı)',
        ),
        'Delilleri tanır',
      );
      await tester.tap(find.text('Kursu aç'));
      await tester.pumpAndSettle();
      expect(repo.calls, [
        'course null Fıkıh Usulü fikih false orta Delilleri tanır',
      ]);
    });

    testWidgets('kurs sayfasından kaydedilir ve çıkarılır', (tester) async {
      await pump(tester, const CoursePage(courseId: 'c2'));
      await tester.tap(find.byTooltip('Kursu kaydet'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kaydedildi. Kurslarım sayfasında bulursun.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Kayıtlılardan çıkar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Kursu kaydet'), findsOneWidget);
      expect(repo.calls, ['saved c2 true', 'saved c2 false']);
    });

    testWidgets('rıza yoksa kaydetmek rıza sayfasını açar, kaydetmez', (
      tester,
    ) async {
      repo.consent = false;
      await pump(tester, const CoursePage(courseId: 'c2'));
      await tester.tap(find.byTooltip('Kursu kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Online Medrese rızası'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.byTooltip('Kursu kaydet'), findsOneWidget);
    });

    testWidgets('kaydedilen başlanmamış kurs Kurslarım sayfasında', (
      tester,
    ) async {
      // Başka telefonda kaydedilmiş gibi: sunucudan gelir.
      repo.savedList.add('c2');
      await pump(tester, const MyCoursesPage());
      expect(find.text('Kaydettiklerin'), findsOneWidget);
      expect(find.text('Siyer-i Nebi'), findsOneWidget);
      expect(find.textContaining('Henüz bir kursa'), findsNothing);
    });

    testWidgets('2.9 telefon kayıtları sunucuya taşınır, telefondan silinir', (
      tester,
    ) async {
      final at = DateTime(2026, 11);
      legacy.entries.addAll({
        'u1:c2': at,
        // Yayından kalkmış kurs ve başka kullanıcının kaydı taşınmaz.
        'u1:gone': at,
        'u2:c1': at,
      });
      await pump(tester, const MyCoursesPage());
      expect(repo.calls, ['import c2']);
      expect(find.text('Siyer-i Nebi'), findsOneWidget);
      expect(legacy.entries.keys, ['u2:c1']);
    });

    testWidgets('taşınamayan telefon kayıtları silinmez, rızasız taşınmaz', (
      tester,
    ) async {
      legacy.entries['u1:c2'] = DateTime(2026, 11);
      repo.importFails = true;
      await pump(tester, const MyCoursesPage());
      expect(repo.calls, ['import c2']);
      expect(legacy.entries.keys, ['u1:c2']);

      repo
        ..calls.clear()
        ..consent = false;
      await pump(tester, const MyCoursesPage());
      expect(repo.calls, isEmpty);
    });

    testWidgets('yönetici derse PDF seçmeden kaynak ekleyemez', (
      tester,
    ) async {
      repo.admin = true;
      await pump(
        tester,
        const AdminResourcesPage(courseId: 'c1', lessonId: 'l2'),
      );
      expect(find.textContaining('Bu derste kaynak yok'), findsOneWidget);
      expect(find.text('PDF seç'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kaynağın adı'),
        'Ders notu',
      );
      await tester.tap(find.text('Kaynağı ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Önce bir PDF seç.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });
  });
}

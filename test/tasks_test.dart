import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:e_medrese/presentation/features/medrese/medrese_page.dart';
import 'package:e_medrese/presentation/features/tasks/ranking_page.dart';
import 'package:e_medrese/presentation/features/tasks/score_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// Bugün Çarşamba 28.10; dönem Salı 27.10'da başlıyor (27.10 – 02.11).
final _today = DateTime.utc(2026, 10, 28);
final _program = TaskProgram(
  startDate: DateTime.utc(2026, 10, 27),
  active: true,
);

Medrese _medrese(
  MemberRole role, {
  String id = 'm1',
  String name = 'Süleymaniye',
}) => Medrese(
  id: id,
  name: name,
  description: '',
  inviteCode: 'AB12CD34',
  myRole: role,
);

void main() {
  late FakeTaskRepository tasks;
  late FakeMedreseRepository medreses;

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    TaskProgram? program,
    List<WeeklyScore> scores = const [],
  }) async {
    tasks = FakeTaskRepository(taskProgram: program)..scoreList.addAll(scores);
    // Bütün kartlar ve günler ekrana sığsın.
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(medreses),
          taskRepositoryProvider.overrideWithValue(tasks),
          todayProvider.overrideWithValue(_today),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTask(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  setUp(() => medreses = FakeMedreseRepository());

  testWidgets('öğrenci ana sayfasında görevler kare kartlar', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage(), program: _program);

    expect(find.text('Bu dönem: 27.10 – 02.11'), findsOneWidget);
    // Dönem sürerken puan gösterilmez.
    expect(find.textContaining('puan'), findsNothing);
    for (final t in testTasks) {
      expect(find.text(t.title), findsOneWidget);
    }
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('program yoksa ya da hocaysa görev kartı yok', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage());
    expect(find.byType(GridView), findsNothing);

    medreses = FakeMedreseRepository()
      ..medreses.add(_medrese(MemberRole.teacher));
    await pump(tester, const HomePage(), program: _program);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('namaz vakti işaretlenir, gelecek günler kapalı', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage(), program: _program);
    await openTask(tester, 'Namaz');

    expect(find.text('Bu gün henüz gelmedi.'), findsNWidgets(5));
    await tester.tap(find.widgetWithText(FilterChip, 'Sabah').at(1));
    await tester.pumpAndSettle();

    expect(tasks.calls, ['namaz 28 0 1']);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sabah').at(1))
          .selected,
      isTrue,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Sabah').at(1));
    await tester.pumpAndSettle();
    expect(tasks.calls.last, 'namaz 28 0 null');
  });

  testWidgets('ders yalnızca Salı ve Perşembe', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage(), program: _program);
    await openTask(tester, 'Derse katılım');

    expect(find.text('27.10 Salı'), findsOneWidget);
    expect(find.text('29.10 Perşembe'), findsOneWidget);
    expect(find.textContaining('Çarşamba'), findsNothing);
  });

  testWidgets('risale hazır seçenek ve elle sayfa', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage(), program: _program);
    await openTask(tester, 'Risale-i Nur okuma');

    await tester.tap(find.text('Okudum (3 sayfa)').first);
    await tester.pumpAndSettle();
    expect(tasks.calls, ['risale 27 0 3']);

    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tasks.calls.last, 'risale 28 0 10');
  });

  testWidgets('cevşen haftada bir kez kaç kez bitirildiği işaretlenir', (
    tester,
  ) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage(), program: _program);
    expect(find.text('Bu hafta bekliyor'), findsOneWidget);
    await openTask(tester, 'Cevşen okuma');

    expect(find.text('Bu hafta kaç kez bitirdin?'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.text('2 kez'));
    await tester.pumpAndSettle();
    // Dönemin ilk gününe (27.10) yazılır.
    expect(tasks.calls, ['cevsen 27 0 2']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bu hafta yapıldı'), findsOneWidget);
  });

  testWidgets('öğrenci uyum kartını görür ama işaretleyemez', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(tester, const HomePage(), program: _program);
    expect(find.text('Hocan değerlendirir'), findsOneWidget);
    await openTask(tester, 'Uyum');

    expect(find.textContaining('Bu puanı hocan verir'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  WeeklyScore score(
    String id,
    String name,
    num total, {
    bool opened = false,
    int day = 21,
    String note = '',
  }) => WeeklyScore(
    studentId: id,
    studentName: name,
    periodStart: DateTime.utc(2026, 10, day),
    total: total,
    details: {'namaz': 25, 'cuz': 60, 'kitap': total - 85},
    opened: opened,
    note: note,
  );

  // Dönem 21.10'da başlamış: 21–27 bitti, sandık bugün (28.10) açılır.
  final chestProgram = TaskProgram(
    startDate: DateTime.utc(2026, 10, 21),
    active: true,
  );

  testWidgets('dönem bitince sandık açılır, puanlar sayılır', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(
      tester,
      const HomePage(),
      program: chestProgram,
      scores: [score('u1', 'Ben', 88.5714)],
    );

    await openTask(tester, 'Haftalık sandığın hazır!');
    expect(find.text('Açmak için 3 kez dokun'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.redeem));
      await tester.pumpAndSettle();
    }

    expect(tasks.calls, ['open 21']);
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('+60'), findsOneWidget);
    expect(find.text('+3,57'), findsOneWidget);
    expect(find.text('88,57 puan'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Haftalık sandığın hazır!'), findsNothing);
  });

  testWidgets('sandıkta hocanın uyum puanı ve notu gösterilir', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(
      tester,
      const HomePage(),
      program: chestProgram,
      scores: [score('u1', 'Ben', 105, note: 'Bu hafta çok gayretliydin.')],
    );
    tasks.scoreList[0] = WeeklyScore(
      studentId: 'u1',
      studentName: 'Ben',
      periodStart: DateTime.utc(2026, 10, 21),
      total: 105,
      details: {'namaz': 25, 'cuz': 60, 'uyum': 20},
      opened: false,
      note: 'Bu hafta çok gayretliydin.',
    );

    await openTask(tester, 'Haftalık sandığın hazır!');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.redeem));
      await tester.pumpAndSettle();
    }

    expect(find.text('Hocan verdi'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('Hocanın notu'), findsOneWidget);
    expect(find.text('20 / 25'), findsOneWidget);
    expect(find.text('Bu hafta çok gayretliydin.'), findsOneWidget);
    // Notun gecikmeli animasyonu bitsin.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('açılmış sandık ve süren dönem kartı göstermez', (tester) async {
    medreses.medreses.add(_medrese(MemberRole.student));
    await pump(
      tester,
      const HomePage(),
      program: chestProgram,
      scores: [score('u1', 'Ben', 88.5714, opened: true)],
    );
    expect(find.text('Haftalık sandığın hazır!'), findsNothing);

    // Dönemin ortası (27.10 başlangıçlı programda 28.10).
    await pump(
      tester,
      const HomePage(),
      program: _program,
      scores: [score('u1', 'Ben', 88.5714)],
    );
    expect(find.text('Haftalık sandığın hazır!'), findsNothing);
  });

  testWidgets('sıralama dönem seçilerek görülür', (tester) async {
    await pump(
      tester,
      RankingPage(medrese: _medrese(MemberRole.student)),
      scores: [
        score('s9', 'Veli', 95),
        score('u1', 'Ben', 88.5714),
        score('u1', 'Ben', 100, day: 14),
      ],
    );
    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(names, ['Veli', 'Ben (sen)']);
    expect(find.text('88,57 puan'), findsOneWidget);

    await tester.ensureVisible(find.text('14.10 – 20.10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14.10 – 20.10'));
    await tester.pumpAndSettle();
    expect(find.text('100 puan'), findsOneWidget);
    expect(find.text('Veli'), findsNothing);
  });

  testWidgets('geçmişte açılmayan sandık belirtilir', (tester) async {
    await pump(
      tester,
      ScoreHistoryPage(medrese: _medrese(MemberRole.student)),
      scores: [score('u1', 'Ben', 88.5714), score('s9', 'Veli', 95)],
    );
    expect(find.text('88,57 puan'), findsOneWidget);
    expect(find.text('95 puan'), findsNothing);
    expect(find.textContaining('otomatik aktarıldı'), findsOneWidget);
  });

  testWidgets('hoca görevleri başlatır, puanları dönem içinde görmez', (
    tester,
  ) async {
    medreses.memberList.addAll([
      Member(
        userId: 'u1',
        name: 'Hoca',
        role: MemberRole.owner,
        joinedAt: _today,
      ),
      Member(
        userId: 's1',
        name: 'Ali',
        role: MemberRole.student,
        joinedAt: _today,
      ),
    ]);
    await pump(tester, MedresePage(medrese: _medrese(MemberRole.owner)));
    await openTask(tester, 'Görev takibi');

    await tester.tap(find.widgetWithText(FilledButton, 'Görevleri başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Başlat'));
    await tester.pumpAndSettle();
    expect(tasks.calls, ['start']);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.textContaining(' puan'), findsNothing);
    expect(find.text('Uyum verilmedi'), findsOneWidget);

    await tester.tap(find.byTooltip('Uyum puanı ver'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 25'), findsOneWidget);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(20);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Aferin');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(tasks.calls.last, 'uyum s1 20 Aferin');
    expect(find.text('Uyum: 20/25'), findsOneWidget);
  });
}

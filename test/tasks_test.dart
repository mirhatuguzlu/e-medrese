import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:e_medrese/presentation/features/medrese/medrese_page.dart';
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
  }) async {
    tasks = FakeTaskRepository(taskProgram: program);
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

    expect(find.text('Bu dönem (27.10 – 02.11): 0 puan'), findsOneWidget);
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
    expect(find.text('Bu dönem: 0,71 puan (en fazla 25)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Sabah').at(1));
    await tester.pumpAndSettle();
    expect(tasks.calls.last, 'namaz 28 0 null');
    expect(find.text('Bu dönem: 0 puan (en fazla 25)'), findsOneWidget);
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
    // 13 sayfa * 25 / 21
    expect(find.text('Bu dönem: 15,48 puan (en fazla 75)'), findsOneWidget);
  });

  testWidgets('hoca görevleri başlatır, öğrencileri puana göre görür', (
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
      Member(
        userId: 's2',
        name: 'Veli',
        role: MemberRole.student,
        joinedAt: _today,
      ),
    ]);
    await pump(tester, MedresePage(medrese: _medrese(MemberRole.owner)));
    tasks.entryList.addAll([
      for (var i = 0; i < 5; i++)
        TaskEntry(
          studentId: 's2',
          taskId: 'namaz',
          day: _today,
          item: i,
          value: 1,
        ),
      TaskEntry(
        studentId: 's2',
        taskId: 'cuz',
        day: _today,
        item: 0,
        value: 80,
      ),
    ]);
    await openTask(tester, 'Görev takibi');

    await tester.tap(find.widgetWithText(FilledButton, 'Görevleri başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Başlat'));
    await tester.pumpAndSettle();
    expect(tasks.calls, ['start']);

    // Veli: 5 vakit (3,57) + 60 sayfa cüz (sınır) = 63,57; önce o gelir.
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.first.title! as Text).data, 'Veli');
    expect(find.text('63,57 puan'), findsOneWidget);

    await tester.tap(find.text('Veli'));
    await tester.pumpAndSettle();
    expect(find.text('Toplam: 63,57 puan'), findsOneWidget);
    expect(find.text('80 sayfa'), findsOneWidget);
    expect(find.text('60 puan'), findsOneWidget);
  });
}

import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/rewards/reward_requests_page.dart';
import 'package:e_medrese/presentation/features/rewards/rewards_page.dart';
import 'package:e_medrese/presentation/features/tasks/tasks_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

int? _perDay(GoalPlan p, String id) =>
    p.needs.firstWhere((n) => n.task.id == id).perDay;
int _perWeek(GoalPlan p, String id) =>
    p.needs.firstWhere((n) => n.task.id == id).perWeek;

void main() {
  test('yarım dönem sayılmaz', () {
    final start = DateTime.utc(2026, 10, 27);
    expect(weeksUntil(start, DateTime.utc(2026, 11, 2)), 1);
    expect(weeksUntil(start, DateTime.utc(2026, 10, 31)), 0);
    expect(weeksUntil(start, DateTime.utc(2026, 11, 23)), 4);
  });

  test('namaz tam, kalan diğerlerine max oranında; uyum yok', () {
    // Haftada 250: namaz 25, kalan 225 / 315 = 5/7 her görevin max'ından.
    final p = planGoal(tasks: testTasks, total: 0, threshold: 1000, weeks: 4);
    expect(p.reachable, isTrue);
    expect(_perWeek(p, 'namaz'), 35);
    expect(_perDay(p, 'namaz'), 5);
    expect(_perWeek(p, 'risale'), 45);
    expect(_perDay(p, 'risale'), 7);
    expect(_perWeek(p, 'kitap'), 150);
    expect(_perDay(p, 'kitap'), 22);
    expect(_perWeek(p, 'cuz'), 43);
    expect(_perWeek(p, 'ders'), 2);
    expect(_perDay(p, 'ders'), isNull);
    expect(_perWeek(p, 'cevsen'), 3);
    expect(p.needs.any((n) => n.task.id == 'uyum'), isFalse);
  });

  test('namaz yetiyorsa yalnız namaz istenir', () {
    final p = planGoal(tasks: testTasks, total: 50, threshold: 100, weeks: 2);
    expect(p.needs.map((n) => n.task.id), ['namaz']);
  });

  test('yetişmiyorsa hepsi tam istenir', () {
    final p = planGoal(tasks: testTasks, total: 0, threshold: 1000, weeks: 2);
    expect(p.reachable, isFalse);
    expect(_perWeek(p, 'kitap'), 210);
  });

  test('ulaşıldıysa öneri yok; süre bittiyse yetişmez', () {
    expect(
      planGoal(tasks: testTasks, total: 1000, threshold: 1000, weeks: 3).needs,
      isEmpty,
    );
    expect(
      planGoal(tasks: testTasks, total: 0, threshold: 10, weeks: 0).reachable,
      isFalse,
    );
  });

  test('istenen ve teslim edilen ödüllerin puanı düşülür', () {
    final scores = [
      WeeklyScore(
        studentId: 'u1',
        studentName: '',
        periodStart: DateTime.utc(2026, 10, 6),
        total: 1200,
        details: const {},
        opened: true,
      ),
    ];
    final claims = [
      RewardClaim(
        id: 'c1',
        rewardId: 'r1',
        studentId: 'u1',
        studentName: '',
        title: 'Kitap',
        points: 1000,
        requestedAt: DateTime(2026, 11),
      ),
    ];
    expect(rewardBalance(scores, claims, 'u1'), 200);
    expect(rewardBalance(scores, const [], 'u1'), 1200);
    expect(rewardBalance(scores, claims, 'u2'), 0);
  });

  test('bu hafta yapılan düşülür, kalan günlere bölünür', () {
    final p = planGoal(tasks: testTasks, total: 0, threshold: 1000, weeks: 4);
    final kitap = p.needs.firstWhere((n) => n.task.id == 'kitap');
    expect(leftThisWeek(kitap, 30, 6), (left: 120, perDay: 20));
    expect(leftThisWeek(kitap, 200, 6), (left: 0, perDay: 0));
    final ders = p.needs.firstWhere((n) => n.task.id == 'ders');
    expect(leftThisWeek(ders, 1, 6), (left: 1, perDay: null));
  });

  late FakeRewardRepository rewards;
  late FakeTaskRepository tasks;

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          ...pushOverrides(rewards: rewards),
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(
            FakeMedreseRepository()..medreses.add(_medrese(MemberRole.student)),
          ),
          taskRepositoryProvider.overrideWithValue(tasks),
          todayProvider.overrideWithValue(DateTime.utc(2026, 10, 28)),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    rewards = FakeRewardRepository()
      ..rewardList.add(
        const Reward(id: 'r1', title: 'Kitap', description: '', points: 1000),
      );
    tasks = FakeTaskRepository(
      taskProgram: TaskProgram(
        startDate: DateTime.utc(2026, 10, 27),
        active: true,
      ),
    );
  });

  testWidgets('ana sayfada hedef önerisi, bu haftanın kalanı ve uyum notu', (
    tester,
  ) async {
    rewards.myGoal = RewardGoal(
      rewardId: 'r1',
      deadline: DateTime.utc(2026, 11, 23),
    );
    tasks.entryList.add(
      TaskEntry(
        studentId: 'u1',
        taskId: 'kitap',
        day: DateTime.utc(2026, 10, 27),
        item: 0,
        value: 30,
      ),
    );
    await pump(tester, const TasksTabPage());

    expect(find.text('Hedef: Kitap'), findsOneWidget);
    expect(
      find.text('1000 puan kaldı, 4 hafta: haftada en az 250 puan.'),
      findsOneWidget,
    );
    expect(
      find.text('• Namaz: her gün 5 vakit, hepsi kılınmalı'),
      findsOneWidget,
    );
    expect(
      find.text(
        '• İslami kitap okuma: günde en az 22 sayfa; '
        'bu hafta 120 sayfa kaldı (günde 20)',
      ),
      findsOneWidget,
    );
    expect(
      find.text('• Cevşen okuma: haftada en az 3 kez; bu hafta 3 kez kaldı'),
      findsOneWidget,
    );
    expect(find.textContaining('Uyum puanı hesaba katılmadı'), findsOneWidget);
  });

  testWidgets('puana ulaşmadan ödül istenemez', (tester) async {
    await pump(tester, RewardsPage(medrese: _medrese(MemberRole.student)));
    expect(find.text('Ödülü iste'), findsNothing);
    expect(find.textContaining('1000 puan kaldı'), findsOneWidget);
  });

  testWidgets('öğrenci ödülü ister, hoca teslim eder, puan düşülür', (
    tester,
  ) async {
    tasks.scoreList.add(
      WeeklyScore(
        studentId: 'u1',
        studentName: 'Ali',
        periodStart: DateTime.utc(2026, 10, 20),
        total: 1200,
        details: const {},
        opened: true,
      ),
    );
    await pump(tester, RewardsPage(medrese: _medrese(MemberRole.student)));
    expect(find.text('Birikmiş puanın: 1200'), findsOneWidget);
    await tester.tap(find.text('Ödülü iste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İste'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('İstedin; hocan teslim edecek.'),
      findsOneWidget,
    );
    expect(find.text('Birikmiş puanın: 200'), findsOneWidget);
    expect(find.text('Ödülü iste'), findsNothing);

    await pump(
      tester,
      RewardRequestsPage(medrese: _medrese(MemberRole.teacher)),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Teslim edildi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Teslim edildi'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Teslim edildi'), findsNothing);
    expect(find.textContaining('teslim:'), findsOneWidget);
  });

  testWidgets('istek yoksa hocanın teslim edecek bir şeyi yok', (tester) async {
    await pump(
      tester,
      RewardRequestsPage(medrese: _medrese(MemberRole.teacher)),
    );
    expect(find.text('Henüz ödül isteyen öğrenci yok.'), findsOneWidget);
    expect(find.text('Teslim edildi'), findsNothing);
  });
}

Medrese _medrese(MemberRole role) => Medrese(
  id: 'm1',
  name: 'Süleymaniye',
  description: '',
  inviteCode: 'AB12CD34',
  myRole: role,
);

import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/domain/entities/task.dart';
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

  testWidgets('ana sayfada hedef önerisi ve uyum notu', (tester) async {
    final medreses = FakeMedreseRepository()
      ..medreses.add(
        const Medrese(
          id: 'm1',
          name: 'Süleymaniye',
          description: '',
          inviteCode: 'AB12CD34',
          myRole: MemberRole.student,
        ),
      );
    final rewards = FakeRewardRepository()
      ..rewardList.add(
        const Reward(id: 'r1', title: 'Kitap', description: '', points: 1000),
      )
      ..myGoal = RewardGoal(
        rewardId: 'r1',
        deadline: DateTime.utc(2026, 11, 23),
      );
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...pushOverrides(rewards: rewards),
          sessionProvider.overrideWith((ref) => Stream.value(testSession)),
          medreseRepositoryProvider.overrideWithValue(medreses),
          taskRepositoryProvider.overrideWithValue(
            FakeTaskRepository(
              taskProgram: TaskProgram(
                startDate: DateTime.utc(2026, 10, 27),
                active: true,
              ),
            ),
          ),
          todayProvider.overrideWithValue(DateTime.utc(2026, 10, 28)),
        ],
        child: const MaterialApp(home: TasksTabPage()),
      ),
    );
    await tester.pumpAndSettle();

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
      find.text('• İslami kitap okuma: günde en az 22 sayfa'),
      findsOneWidget,
    );
    expect(find.textContaining('Uyum puanı hesaba katılmadı'), findsOneWidget);
  });
}

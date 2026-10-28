import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

TaskDefinition _task(num target, num points, num cap) => TaskDefinition(
  id: 't',
  title: '',
  description: '',
  kind: TaskKind.pages,
  target: target,
  points: points,
  cap: cap,
);

void main() {
  test('namaz: 35 vakit 25 puan', () {
    final namaz = _task(35, 25, 35);
    expect(formatPoints(namaz.score(35)), '25');
    expect(formatPoints(namaz.score(10)), '7,14');
    expect(formatPoints(namaz.score(1)), '0,71');
    expect(formatPoints(namaz.score(0)), '0');
  });

  test('risale: 21 sayfa 25 puan, 63 sayfadan sonrası sayılmaz', () {
    final risale = _task(21, 25, 63);
    expect(formatPoints(risale.score(21)), '25');
    expect(formatPoints(risale.score(63)), '75');
    expect(formatPoints(risale.score(100)), '75');
    expect(formatPoints(risale.score(10)), '11,90');
  });

  test('ders: her ders 15 puan, en fazla 2 ders', () {
    final ders = _task(2, 30, 2);
    expect(formatPoints(ders.score(1)), '15');
    expect(formatPoints(ders.score(2)), '30');
    expect(formatPoints(ders.score(3)), '30');
  });

  test('cüz: sayfa başına 1 puan, en fazla 60', () {
    final cuz = _task(20, 20, 60);
    expect(formatPoints(cuz.score(20)), '20');
    expect(formatPoints(cuz.score(25)), '25');
    expect(formatPoints(cuz.score(80)), '60');
  });

  test('kitap: 70 sayfa 25 puan, 210 sayfadan sonrası sayılmaz', () {
    final kitap = _task(70, 25, 210);
    expect(formatPoints(kitap.score(70)), '25');
    expect(formatPoints(kitap.score(10)), '3,57');
    expect(formatPoints(kitap.score(300)), '75');
    expect(formatPoints(kitap.maxScore), '75');
  });

  test('dönem: başlangıçtan itibaren 7 günlük', () {
    final program = TaskProgram(
      startDate: DateTime.utc(2026, 10, 20),
      active: true,
    );
    expect(
      program.periodStart(DateTime(2026, 10, 20)),
      DateTime.utc(2026, 10, 20),
    );
    expect(
      program.periodStart(DateTime(2026, 10, 26, 23)),
      DateTime.utc(2026, 10, 20),
    );
    expect(
      program.periodStart(DateTime(2026, 10, 27)),
      DateTime.utc(2026, 10, 27),
    );
    expect(
      program.periodDays(DateTime(2026, 10, 28)).last,
      DateTime.utc(2026, 11, 2),
    );
  });

  test('toplam yalnızca öğrencinin o görevdeki girdileri', () {
    final namaz = _task(35, 25, 35);
    final day = DateTime.utc(2026, 10, 27);
    TaskEntry e(String s, String t, num v) =>
        TaskEntry(studentId: s, taskId: t, day: day, item: 0, value: v);
    expect(
      taskTotal(namaz, 'a', [
        e('a', 't', 1),
        e('a', 't', 1),
        e('b', 't', 1),
        e('a', 'x', 5),
      ]),
      2,
    );
  });
}

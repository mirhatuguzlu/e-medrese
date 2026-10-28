import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [TaskRepository].
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(Supabase.instance.client),
);

/// Bugün (saat olmadan). Testlerde sabitlenir.
final todayProvider = Provider<DateTime>((ref) => dateOnly(DateTime.now()));

/// Görev tanımları.
final taskDefinitionsProvider =
    FutureProvider<Result<List<TaskDefinition>, AppFailure>>(
      (ref) => ref.watch(taskRepositoryProvider).definitions(),
    );

/// Medresenin görev programı; hiç başlatılmadıysa `null`.
final AutoDisposeFutureProviderFamily<Result<TaskProgram?, AppFailure>, String>
taskProgramProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(taskRepositoryProvider).program(medreseId),
);

/// Medresenin bir dönemdeki girdileri. Öğrenci yalnızca kendininkileri alır
/// (RLS), hocalar herkesinkini.
final AutoDisposeFutureProviderFamily<
  Result<List<TaskEntry>, AppFailure>,
  ({String medreseId, DateTime periodStart})
>
periodEntriesProvider = FutureProvider.autoDispose.family(
  (ref, key) => ref
      .watch(taskRepositoryProvider)
      .entries(medreseId: key.medreseId, periodStart: key.periodStart),
);

/// Medresenin biten dönemlerdeki bütün puanları (sıralama ve geçmiş için).
final AutoDisposeFutureProviderFamily<
  Result<List<WeeklyScore>, AppFailure>,
  String
>
weeklyScoresProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(taskRepositoryProvider).weeklyScores(medreseId),
);

final _day = DateFormat('yyyy-MM-dd');

/// Görev programı ve öğrenci girdileri.
class TaskRepository {
  /// Supabase istemcisiyle oluşturur.
  TaskRepository(this._client);

  final SupabaseClient _client;

  /// Görev tanımları, sırasıyla.
  Future<Result<List<TaskDefinition>, AppFailure>> definitions() =>
      guardSupabase(() async {
        final rows = await _client
            .from('task_definitions')
            .select('id, title, description, config')
            .order('sort');
        return rows.map(TaskDefinition.fromJson).toList();
      });

  /// Medresenin programı.
  Future<Result<TaskProgram?, AppFailure>> program(String medreseId) =>
      guardSupabase(() async {
        final row = await _client
            .from('task_programs')
            .select('start_date, active')
            .eq('medrese_id', medreseId)
            .maybeSingle();
        return row == null ? null : TaskProgram.fromJson(row);
      });

  /// Programı [today]'den başlatır (durdurulmuşsa yeniden başlatır).
  Future<Result<void, AppFailure>> start(String medreseId, DateTime today) =>
      guardSupabase(
        () => _client.from('task_programs').upsert({
          'medrese_id': medreseId,
          'start_date': _day.format(today),
          'active': true,
        }),
      );

  /// Programı durdurur; girdiler silinmez.
  Future<Result<void, AppFailure>> stop(String medreseId) => guardSupabase(
    () => _client
        .from('task_programs')
        .update({'active': false})
        .eq('medrese_id', medreseId),
  );

  /// [periodStart]'tan başlayan 7 günün girdileri.
  Future<Result<List<TaskEntry>, AppFailure>> entries({
    required String medreseId,
    required DateTime periodStart,
  }) => guardSupabase(() async {
    final rows = await _client
        .from('task_entries')
        .select('student_id, task_id, day, item, value')
        .eq('medrese_id', medreseId)
        .gte('day', _day.format(periodStart))
        .lte('day', _day.format(periodStart.add(const Duration(days: 6))));
    return rows.map(TaskEntry.fromJson).toList();
  });

  /// Öğrencinin [day] günündeki girdisini yazar; [value] `null` ise siler
  /// (işaretlenmemiş = puan yok).
  Future<Result<void, AppFailure>> setEntry({
    required String medreseId,
    required String studentId,
    required String taskId,
    required DateTime day,
    required int item,
    required num? value,
  }) => guardSupabase(() async {
    final key = {
      'medrese_id': medreseId,
      'student_id': studentId,
      'task_id': taskId,
      'day': _day.format(day),
      'item': item,
    };
    if (value == null) {
      await _client.from('task_entries').delete().match(key);
    } else {
      await _client.from('task_entries').upsert({...key, 'value': value});
    }
  });

  /// Biten dönemleri kaydettirip medresenin bütün haftalık puanlarını döner;
  /// en yeni dönem önce, dönem içinde puana göre.
  Future<Result<List<WeeklyScore>, AppFailure>> weeklyScores(
    String medreseId,
  ) => guardSupabase(() async {
    await _client.rpc<void>('finalize_task_scores', params: {'m': medreseId});
    final rows = await _client
        .from('weekly_scores')
        .select(
          'student_id, period_start, total, details, opened_at, '
          'student:profiles(full_name)',
        )
        .eq('medrese_id', medreseId)
        .order('period_start', ascending: false)
        .order('total', ascending: false);
    return rows.map(WeeklyScore.fromJson).toList();
  });

  /// [periodStart] döneminin sandığını açar; puanı döner.
  Future<Result<WeeklyScore, AppFailure>> openChest({
    required String medreseId,
    required DateTime periodStart,
  }) => guardSupabase(() async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'open_chest',
      params: {'m': medreseId, 'p': _day.format(periodStart)},
    );
    return WeeklyScore.fromJson(row);
  });
}

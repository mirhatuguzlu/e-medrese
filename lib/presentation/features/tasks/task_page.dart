import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Öğrencinin bir görevi bu dönemin günlerinde işaretlediği sayfa.
///
/// Bugünden sonraki günler kapalı; işaretlenmeyen gün puan getirmez.
class TaskPage extends ConsumerWidget {
  /// [task] sayfası.
  const TaskPage({
    required this.medrese,
    required this.task,
    required this.program,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Görev.
  final TaskDefinition task;

  /// Medresenin programı.
  final TaskProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final weekly = task.kind == TaskKind.weekly;
    // Haftalık görev dönemin ilk gününe tek girdi olarak yazılır.
    final days = weekly
        ? [program.periodStart(today)]
        : program.periodDays(today).where(task.isOn).toList();
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    final key = (
      medreseId: medrese.id,
      periodStart: program.periodStart(today),
    );
    final entries = switch (ref.watch(periodEntriesProvider(key))) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };

    Future<void> save(DateTime day, int item, num? value) async {
      final result = await ref
          .read(taskRepositoryProvider)
          .setEntry(
            medreseId: medrese.id,
            studentId: myId,
            taskId: task.id,
            day: day,
            item: item,
            value: value,
          );
      ref.invalidate(periodEntriesProvider(key));
      if (result case Err(:final error) when context.mounted) {
        context.showMessage(error.message);
      }
    }

    num? valueOf(DateTime day, int item) => entries
        ?.where(
          (e) =>
              e.taskId == task.id &&
              e.studentId == myId &&
              e.day == day &&
              e.item == item,
        )
        .firstOrNull
        ?.value;

    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.description),
                      const SizedBox(height: 8),
                      Text(
                        'Puanın dönem bitince sandıkta açıklanır.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                for (final day in days)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekly
                                ? 'Bu hafta kaç kez bitirdin?'
                                : day == today
                                ? '${formatDay(day)} (bugün)'
                                : formatDay(day),
                            style: theme.textTheme.titleSmall,
                          ),
                          if (weekly)
                            Wrap(
                              spacing: 8,
                              children: [
                                for (var n = 1; n <= task.cap; n++)
                                  ChoiceChip(
                                    label: Text('$n kez'),
                                    selected: valueOf(day, 0) == n,
                                    onSelected: (on) =>
                                        save(day, 0, on ? n : null),
                                  ),
                              ],
                            )
                          else if (day.isAfter(today))
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Bu gün henüz gelmedi.'),
                            )
                          else if (task.kind == TaskKind.checks)
                            Wrap(
                              spacing: 8,
                              children: [
                                for (var i = 0; i < task.items.length; i++)
                                  FilterChip(
                                    label: Text(task.items[i]),
                                    selected: valueOf(day, i) != null,
                                    onSelected: (on) =>
                                        save(day, i, on ? 1 : null),
                                  ),
                              ],
                            )
                          else
                            _PagesInput(
                              // Değer değişince alan yeniden kurulsun.
                              key: ValueKey('$day-${valueOf(day, 0)}'),
                              presets: task.presets,
                              value: valueOf(day, 0),
                              onChanged: (pages) => save(day, 0, pages),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Bir günün sayfa girişi: hazır seçenekler ya da elle sayfa sayısı.
/// Seçili seçeneğe yeniden dokunmak ya da alanı boşaltmak işareti kaldırır.
class _PagesInput extends StatefulWidget {
  const _PagesInput({
    required this.presets,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<TaskPreset> presets;
  final num? value;
  final ValueChanged<num?> onChanged;

  @override
  State<_PagesInput> createState() => _PagesInputState();
}

class _PagesInputState extends State<_PagesInput> {
  // Hazır seçenek seçiliyse alan boş kalır.
  late final TextEditingController _pages = TextEditingController(
    text:
        widget.value == null ||
            widget.presets.any((p) => p.pages == widget.value)
        ? ''
        : '${widget.value}',
  );

  // Yalnızca elle yazılınca kaydet; boş alan seçili hazır seçeneği silmesin.
  bool _edited = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _submitPages() {
    if (!_edited) return;
    _edited = false;
    final text = _pages.text.trim();
    final pages = text.isEmpty ? null : int.tryParse(text);
    if (pages != widget.value) widget.onChanged(pages);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.presets.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final p in widget.presets)
                ChoiceChip(
                  label: Text(p.label),
                  selected: widget.value == p.pages,
                  onSelected: (on) => widget.onChanged(on ? p.pages : null),
                ),
            ],
          ),
        TextField(
          controller: _pages,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: widget.presets.isEmpty
                ? 'Okuduğun sayfa'
                : 'Başka: okuduğun sayfa',
            suffixText: 'sayfa',
          ),
          onChanged: (_) => _edited = true,
          onSubmitted: (_) => _submitPages(),
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            _submitPages();
          },
        ),
      ],
    );
  }
}

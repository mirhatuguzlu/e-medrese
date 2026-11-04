import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dersin tekrar soruları, birer birer: şık seçilir, kontrol edilince doğrusu
/// ve açıklaması görünür. İlk cevaplar kaydedilir; yeniden çözmek serbesttir.
class LessonQuizPage extends ConsumerStatefulWidget {
  /// [lesson] soruları.
  const LessonQuizPage({required this.lesson, super.key});

  /// Ders (soruları dolu, tamamlanmış olmalı).
  final Lesson lesson;

  @override
  ConsumerState<LessonQuizPage> createState() => _LessonQuizPageState();
}

class _LessonQuizPageState extends ConsumerState<LessonQuizPage> {
  int _index = 0;
  int? _choice;
  bool _checked = false;
  int _correct = 0;

  List<LessonQuestion> get _questions => widget.lesson.questions;

  void _check() {
    final q = _questions[_index];
    final choice = _choice;
    if (choice == null) return;
    final right = choice == q.answer;
    setState(() {
      _checked = true;
      if (right) _correct++;
    });
    unawaited(
      right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact(),
    );
    unawaited(_record(q, choice));
  }

  /// Yalnız ilk cevap kaydedilir; daha önce cevaplandıysa bir şey yapmaz.
  Future<void> _record(LessonQuestion q, int choice) async {
    final known = await ref.read(questionResultsProvider.future);
    if (!mounted) return;
    if (known case Ok(:final value) when value.containsKey(q.id)) return;
    final result = await ref
        .read(courseRepositoryProvider)
        .answerQuestion(questionId: q.id, choice: choice);
    if (!mounted) return;
    if (result case Err(:final error)) context.showMessage(error.message);
    ref.invalidate(questionResultsProvider);
  }

  void _next() => setState(() {
    _index++;
    _choice = null;
    _checked = false;
  });

  void _restart() => setState(() {
    _index = 0;
    _choice = null;
    _checked = false;
    _correct = 0;
  });

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Tekrar soruları')),
      body: _index >= total ? _summary(context, total) : _question(context),
    );
  }

  Widget _question(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = _questions[_index];
    final total = _questions.length;
    final last = _index == total - 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_index + (_checked ? 1 : 0)) / total,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Soru ${_index + 1} / $total',
          style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          q.question,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Option(
              label: String.fromCharCode(65 + i),
              text: q.options[i],
              selected: _choice == i,
              state: !_checked
                  ? null
                  : i == q.answer
                  ? true
                  : _choice == i
                  ? false
                  : null,
              onTap: _checked ? null : () => setState(() => _choice = i),
            ),
          ),
        if (_checked) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: _choice == q.answer
                ? scheme.primaryContainer
                : scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _choice == q.answer
                        ? 'Doğru!'
                        : 'Doğru cevap: '
                              '${String.fromCharCode(65 + q.answer)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (q.explanation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(q.explanation),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: !_checked ? (_choice == null ? null : _check) : _next,
          child: Text(
            !_checked
                ? 'Kontrol et'
                : last
                ? 'Sonucu gör'
                : 'Sonraki soru',
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, int total) {
    final theme = Theme.of(context);
    final all = _correct == total;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          all ? Icons.emoji_events_outlined : Icons.fact_check_outlined,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '$_correct / $total doğru',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          all
              ? 'Maşallah, hepsini bildin.'
              : 'Yanlış yaptığın yerleri videoda yeniden izleyebilirsin.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'İlk cevapların kaydedilir; hocan verdiği kurslarda doğru sayını '
          'görür. Yeniden çözmek kaydı değiştirmez.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.replay),
          label: const Text('Yeniden çöz'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Derse dön'),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.text,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;

  /// Kontrolden sonra: doğru şık `true`, yanlış seçilen `false`.
  final bool? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (border, fill, icon) = switch (state) {
      true => (scheme.primary, scheme.primaryContainer, Icons.check_circle),
      false => (scheme.error, scheme.errorContainer, Icons.cancel),
      null when selected => (
        scheme.primary,
        scheme.surfaceContainerHighest,
        null,
      ),
      null => (scheme.outlineVariant, scheme.surface, null),
    };
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: border,
          width: selected || state != null ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: border,
                foregroundColor: scheme.surface,
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              if (icon != null) Icon(icon, color: border),
            ],
          ),
        ),
      ),
    );
  }
}

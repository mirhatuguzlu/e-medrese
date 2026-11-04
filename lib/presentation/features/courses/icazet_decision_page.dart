import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın bir icazet isteğini onayladığı ya da notuyla geri çevirdiği sayfa.
class IcazetDecisionPage extends ConsumerStatefulWidget {
  /// Bekleyen [request].
  const IcazetDecisionPage({
    required this.request,
    required this.courseTitle,
    super.key,
  });

  /// İstek.
  final IcazetRequest request;

  /// Kursun adı.
  final String courseTitle;

  @override
  ConsumerState<IcazetDecisionPage> createState() => _IcazetDecisionPageState();
}

class _IcazetDecisionPageState extends ConsumerState<IcazetDecisionPage> {
  final _note = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _decide({required bool approve}) async {
    if (!approve && _note.text.trim().isEmpty) {
      context.showMessage('Geri çevirirken öğrencine nedenini yaz.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .decideIcazet(
          id: widget.request.id,
          approve: approve,
          note: _note.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(icazetRequestsProvider);
        Navigator.of(context).pop();
        context.showMessage(
          approve ? 'İcazet onaylandı.' : 'İstek geri çevrildi.',
        );
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('İcazet isteği')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            displayName(r.studentName),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.courseTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Kursun bütün derslerini bitirdi · ${formatDateTime(r.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Onaylarsan öğrencinin icazet belgesinde adın ve medresen yazar. '
            'Gerekirse önce öğrencinle konuş; tekrar sorularındaki sonucunu '
            'kursun ilerleme sayfasında görebilirsin.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Notun (geri çevirirken zorunlu)',
              helperText: 'Öğrencin görür.',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 1000,
            minLines: 2,
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _loading ? null : () => _decide(approve: true),
            icon: const Icon(Icons.verified),
            label: const Text('İcazeti onayla'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _loading ? null : () => _decide(approve: false),
            child: const Text('Geri çevir'),
          ),
        ],
      ),
    );
  }
}

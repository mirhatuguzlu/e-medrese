import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/consent_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/presentation/features/legal/legal_text_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Görev takibi açık rızasını verme ya da geri alma sayfası.
class TaskConsentPage extends ConsumerStatefulWidget {
  /// Rıza sayfası.
  const TaskConsentPage({super.key});

  @override
  ConsumerState<TaskConsentPage> createState() => _TaskConsentPageState();
}

class _TaskConsentPageState extends ConsumerState<TaskConsentPage> {
  bool _loading = false;
  bool _agreed = false;

  Future<void> _change({required bool give}) async {
    if (!give &&
        !await confirm(
          context,
          title: 'Rızayı geri al',
          message:
              'Bütün görev girdilerin ve haftalık puanların silinecek. '
              'Bu geri alınamaz.',
          action: 'Geri al',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = ref.read(consentRepositoryProvider);
    final result = give
        ? await repo.giveTaskConsent()
        : await repo.revokeTaskConsent();
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref
          ..invalidate(taskConsentProvider)
          ..invalidate(periodEntriesProvider);
        Navigator.of(context).pop();
        context.showMessage(
          give ? 'Görev takibi açıldı.' : 'Rıza geri alındı, veriler silindi.',
        );
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final given = switch (ref.watch(taskConsentProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Görev takibi rızası')),
      body: Column(
        children: [
          const Expanded(child: LegalText(asset: taskConsentAsset)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (given) {
                null => const SizedBox.shrink(),
                true => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Rıza verdin; görev takibi açık.'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loading ? null : () => _change(give: false),
                      child: const Text('Rızamı geri al ve verilerimi sil'),
                    ),
                  ],
                ),
                false => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Okudum; görev takibi verilerimin bu metinde yazdığı '
                        'şekilde işlenmesine açık rıza veriyorum.',
                      ),
                    ),
                    FilledButton(
                      onPressed: _agreed && !_loading
                          ? () => _change(give: true)
                          : null,
                      child: const Text('Rıza ver'),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

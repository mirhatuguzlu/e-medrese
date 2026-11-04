import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/presentation/features/legal/legal_text_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rıza yoksa rıza sayfasını açar; dönünce rıza verildiyse `true`.
Future<bool> ensureCourseConsent(BuildContext context, WidgetRef ref) async {
  bool given() => switch (ref.read(courseConsentProvider)) {
    AsyncData(value: Ok(:final value)) => value,
    _ => false,
  };
  await ref.read(courseConsentProvider.future);
  if (given()) return true;
  if (!context.mounted) return false;
  await context.push(const CourseConsentPage());
  await ref.read(courseConsentProvider.future);
  return given();
}

/// Online Medrese ders ilerlemesi açık rızasını verme ya da geri alma sayfası.
class CourseConsentPage extends ConsumerStatefulWidget {
  /// Rıza sayfası.
  const CourseConsentPage({super.key});

  @override
  ConsumerState<CourseConsentPage> createState() => _CourseConsentPageState();
}

class _CourseConsentPageState extends ConsumerState<CourseConsentPage> {
  bool _loading = false;
  bool _agreed = false;

  Future<void> _change({required bool give}) async {
    if (!give &&
        !await confirm(
          context,
          title: 'Rızayı geri al',
          message:
              'Bütün ders ilerlemen silinecek ve dersleri izleyemeyeceksin. '
              'Bu geri alınamaz.',
          action: 'Geri al',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = ref.read(courseRepositoryProvider);
    final result = give ? await repo.giveConsent() : await repo.revokeConsent();
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref
          ..invalidate(courseConsentProvider)
          ..invalidate(lessonProgressProvider);
        Navigator.of(context).pop();
        context.showMessage(
          give
              ? 'Online Medrese açıldı.'
              : 'Rıza geri alındı, veriler silindi.',
        );
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final given = switch (ref.watch(courseConsentProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Online Medrese rızası')),
      body: Column(
        children: [
          const Expanded(child: LegalText(asset: courseConsentAsset)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (given) {
                null => const SizedBox.shrink(),
                true => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Rıza verdin; dersleri izleyebilirsin.'),
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
                        'Okudum; ders ilerlemelerimin bu metinde yazdığı '
                        "şekilde işlenmesine ve YouTube'a iletilmesine açık "
                        'rıza veriyorum.',
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

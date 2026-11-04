import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Yeni sürüm çıkınca uygulamanın yerine gösterilen sayfa; güncellenene
/// kadar uygulama kullanılamaz.
class UpdateRequiredPage extends StatelessWidget {
  /// Güncelleme sayfası.
  const UpdateRequiredPage({super.key});

  Future<void> _download(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(latestApkUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      context.showMessage('İndirme sayfası açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.system_update,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu sürüm artık mevcut değil',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Devam etmek için uygulamanın yeni sürümünü indirip '
                    'kur.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Uygulamayı güncelle'),
                    onPressed: () => _download(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

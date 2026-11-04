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
    final scheme = theme.colorScheme;
    // Düz beyaz ekran "uygulama bozuldu" gibi görünüyordu; renkli zemin ve
    // kart bunun bilinçli bir güncelleme ekranı olduğunu belli eder.
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.primary, scheme.primaryContainer],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              Icons.rocket_launch_rounded,
                              size: 44,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Yeni sürüm hazır',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'e-Medrese güncellendi. Yeni özellikleri ve '
                          'düzeltmeleri kullanmaya devam etmek için yeni '
                          'sürümü indirip kur. Verilerin kaybolmaz.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Uygulamayı güncelle'),
                          onPressed: () => _download(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

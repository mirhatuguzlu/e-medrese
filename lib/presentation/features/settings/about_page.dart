import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final AutoDisposeFutureProvider<PackageInfo> _packageInfoProvider =
    FutureProvider.autoDispose((ref) => PackageInfo.fromPlatform());

/// Sürüm, güncelleme denetimi ve web sitesi.
class AboutPage extends ConsumerStatefulWidget {
  /// Uygulama hakkında.
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    // Yeni sürüm varsa uygulama kendiliğinden güncelleme sayfasına geçer.
    final newer = await ref.refresh(updateRequiredProvider.future);
    if (!mounted) return;
    setState(() => _checking = false);
    if (!newer) context.showMessage('En son sürümü kullanıyorsun.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = ref.watch(_packageInfoProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Uygulama hakkında')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'e-Medrese',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          Text(
            info == null ? '' : 'Sürüm ${info.version} (${info.buildNumber})',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _checking ? null : _check,
            child: Text(_checking ? 'Denetleniyor…' : 'Güncellemeleri denetle'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://mirhatuguzlu.github.io/e-medrese/'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Web sitesi ve yenilikler'),
          ),
        ],
      ),
    );
  }
}

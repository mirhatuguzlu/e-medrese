import 'package:flutter/material.dart';

/// Aydınlatma metni.
const privacyNoticeAsset = 'assets/legal/aydinlatma_metni.txt';

/// Görev takibi açık rıza metni.
const taskConsentAsset = 'assets/legal/acik_riza.txt';

/// Online Medrese (ders ilerlemesi) açık rıza metni.
const courseConsentAsset = 'assets/legal/kurs_riza.txt';

/// Künye ve iletişim.
const imprintAsset = 'assets/legal/kunye.txt';

/// `assets/legal` altındaki bir metni gösteren sayfa. Metinler tek kaynaktır;
/// mağazadaki gizlilik politikası da aynı dosyadır.
class LegalTextPage extends StatelessWidget {
  /// [asset] metnini [title] başlığıyla gösterir.
  const LegalTextPage({required this.title, required this.asset, super.key});

  /// Sayfa başlığı.
  final String title;

  /// Metin dosyası.
  final String asset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: LegalText(asset: asset),
  );
}

/// `# ` ile başlayan satırlar başlık, diğerleri paragraf olarak çizilir.
class LegalText extends StatelessWidget {
  /// [asset] metni.
  const LegalText({required this.asset, super.key});

  /// Metin dosyası.
  final String asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: DefaultAssetBundle.of(context).loadString(asset),
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final line in text.split('\n'))
              if (line.startsWith('# '))
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(
                    line.substring(2),
                    style: theme.textTheme.titleMedium,
                  ),
                )
              else if (line.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
          ],
        );
      },
    );
  }
}

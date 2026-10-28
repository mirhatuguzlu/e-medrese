import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Medresenin davet kodunu gösterir; öğrenciler bu kodla katılır.
class InviteCodePage extends StatelessWidget {
  /// [medrese]'nin davet kodu sayfası.
  const InviteCodePage({required this.medrese, super.key});

  /// Kodu gösterilen medrese.
  final Medrese medrese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Davet kodu')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                medrese.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Öğrencilerin bu kodla medresene katılabilir.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SelectableText(
                medrese.inviteCode,
                style: theme.textTheme.displaySmall?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Kodu kopyala'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: medrese.inviteCode),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Kod kopyalandı.')),
                    );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

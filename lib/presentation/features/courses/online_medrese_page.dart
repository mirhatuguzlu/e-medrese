import 'package:flutter/material.dart';

/// Online Medrese (kurslar). Kurslar henüz yok; "yakında" gösterilir.
class OnlineMedresePage extends StatelessWidget {
  /// Online Medrese sayfası.
  const OnlineMedresePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Online Medrese')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 64, color: theme.hintColor),
              const SizedBox(height: 16),
              Text('Çok yakında', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Online dersler ve kurslar burada olacak.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:e_medrese/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Açık, koyu ya da telefona uyan tema seçimi.
class ThemePage extends ConsumerWidget {
  /// Tema.
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: RadioGroup<ThemeMode>(
        groupValue: mode,
        onChanged: (m) {
          if (m != null) {
            unawaited(ref.read(settingsProvider.notifier).setThemeMode(m));
          }
        },
        child: const Column(
          children: [
            RadioListTile(
              value: ThemeMode.system,
              title: Text('Telefona uy'),
              subtitle: Text('Telefon koyu temadaysa uygulama da koyu olur.'),
            ),
            RadioListTile(value: ThemeMode.light, title: Text('Açık')),
            RadioListTile(value: ThemeMode.dark, title: Text('Koyu')),
          ],
        ),
      ),
    );
  }
}

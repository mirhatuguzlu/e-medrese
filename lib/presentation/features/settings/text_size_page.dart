import 'package:e_medrese/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulamadaki yazı büyüklüğü.
class TextSizePage extends ConsumerWidget {
  /// Yazı boyutu.
  const TextSizePage({super.key});

  static const _labels = ['Küçük', 'Normal', 'Büyük', 'Çok büyük'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(settingsProvider.select((s) => s.textScale));
    final index = SettingsNotifier.textScales.indexOf(scale);
    return Scaffold(
      appBar: AppBar(title: const Text('Yazı boyutu')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            index < 0 ? '' : _labels[index],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Slider(
            value: (index < 0 ? 1 : index).toDouble(),
            max: SettingsNotifier.textScales.length - 1.0,
            divisions: SettingsNotifier.textScales.length - 1,
            label: index < 0 ? null : _labels[index],
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setTextScale(SettingsNotifier.textScales[v.round()]),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Örnek yazı: Bu hafta 5 vakit namazını tam kıldın, '
                "Kur'an-ı Kerim'den 20 sayfa okudun.",
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Telefonun yazı boyutu ayarı da hesaba katılır.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

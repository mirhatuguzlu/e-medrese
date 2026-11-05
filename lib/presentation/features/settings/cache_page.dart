import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// İndirilmiş resimlerin (kurs kapakları, profil fotoğrafları) önbelleğini
/// temizler.
class CachePage extends StatefulWidget {
  /// Önbellek.
  const CachePage({super.key});

  @override
  State<CachePage> createState() => _CachePageState();
}

class _CachePageState extends State<CachePage> {
  bool _loading = false;

  Future<void> _clear() async {
    setState(() => _loading = true);
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (!mounted) return;
    setState(() => _loading = false);
    context.showMessage('Önbellek temizlendi.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Önbellek')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Kurs kapakları ve profil fotoğrafları bir kez indirilip telefonda '
          'saklanır; böylece daha hızlı açılır ve internet harcamaz.\n\n'
          'Temizlersen telefonda yer açılır, resimler gerektiğinde yeniden '
          'indirilir. Hesabın, ilerlemen ve ayarların silinmez.',
        ),
        const SizedBox(height: 24),
        LoadingButton(
          label: 'Önbelleği temizle',
          loading: _loading,
          onPressed: _clear,
        ),
      ],
    ),
  );
}

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/profile_repository.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Profil fotoğrafını galeriden seçme ya da kaldırma sayfası.
class ProfilePhotoPage extends ConsumerStatefulWidget {
  /// Profil fotoğrafı.
  const ProfilePhotoPage({super.key});

  @override
  ConsumerState<ProfilePhotoPage> createState() => _ProfilePhotoPageState();
}

class _ProfilePhotoPageState extends ConsumerState<ProfilePhotoPage> {
  bool _loading = false;

  Future<void> _pick() async {
    // Küçültülür: sunucudaki sınır 1 MB, liste avatarı için 512 px yeter.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final extension = switch (file.name.split('.').last.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    await _run(
      () async => ref
          .read(profileRepositoryProvider)
          .uploadPhoto(await file.readAsBytes(), extension: extension),
    );
  }

  Future<void> _run(Future<Result<void, AppFailure>> Function() action) async {
    setState(() => _loading = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _loading = false);
    ref.invalidate(myProfileProvider);
    if (result case Err(:final error)) context.showMessage(error.message);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        ref.watch(myProfileProvider).valueOrNull?.photoPath != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil fotoğrafı')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: UserAvatar(radius: 72)),
          const SizedBox(height: 24),
          const Text(
            'Fotoğrafını medresendeki üyeler görür. Yalnızca galeriden '
            'seçtiğin fotoğraf yüklenir; kaldırdığında ya da hesabını '
            'sildiğinde sunucudan silinir.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(hasPhoto ? 'Fotoğrafı değiştir' : 'Galeriden seç'),
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _run(ref.read(profileRepositoryProvider).removePhoto),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Fotoğrafı kaldır'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

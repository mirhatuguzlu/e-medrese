import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/legacy_saved_courses.dart';
import 'package:e_medrese/data/repositories/profile_repository.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hesabı ve bütün verileri silme sayfası (KVKK m.7, Google Play).
class DeleteAccountPage extends ConsumerStatefulWidget {
  /// Hesap silme sayfası.
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  bool _loading = false;

  Future<void> _delete() async {
    if (!await confirm(
      context,
      title: 'Hesabı sil',
      message: 'Hesabın ve bütün verilerin kalıcı olarak silinecek.',
      action: 'Sil',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    // Silmeden önce: token silmek için oturum gerekiyor.
    await ref.read(pushServiceProvider).unregister();
    final userId = ref.read(sessionProvider).valueOrNull?.user.id;
    // Fotoğraf Storage'da durur, hesapla birlikte silinmez; önce silinir.
    final profile = await ref
        .read(myProfileProvider.future)
        .catchError((Object _) => null);
    final photo = profile?.photoPath == null
        ? const Ok<void, AppFailure>(null)
        : await ref.read(profileRepositoryProvider).removePhoto();
    final result = photo is Err
        ? photo
        : await ref.read(authRepositoryProvider).deleteAccount();
    // 2.9'dan telefonda kalan kurs kayıtları da silinsin.
    if (result is Ok && userId != null) {
      await ref.read(legacySavedCoursesProvider).remove(userId);
    }
    // Başarılı silmede oturum kapanır, bu sayfa ağaçtan kalkar.
    if (!mounted) return;
    setState(() => _loading = false);
    if (result case Err(:final error)) {
      // Silinemediyse bildirimler bu cihaza gelmeye devam etsin.
      await ref.read(pushServiceProvider).register();
      if (mounted) context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabı sil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Hesabını silersen adın, e-postan, profil fotoğrafın, medrese '
            'üyeliklerin, '
            'paylaşımların, yorumların, duyuruların, görev girdilerin, '
            'puanların ve bildirimlerin kalıcı olarak silinir.\n\n'
            'Kurucusu olduğun ve başka üyesi bulunan bir medrese varsa önce '
            'Üyeler sayfasından başka birini kurucu yapmalısın. Tek üyesi sen '
            'olan medreseler hesabınla birlikte silinir.\n\n'
            '5651 sayılı Kanun gereği içerik oluşturma kayıtları (zaman ve IP '
            'adresi) ve şikayet kayıtları 2 yıl saklanır, sonra silinir.',
          ),
          const SizedBox(height: 24),
          LoadingButton(
            label: 'Hesabımı kalıcı olarak sil',
            loading: _loading,
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}

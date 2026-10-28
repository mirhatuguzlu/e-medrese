import 'package:e_medrese/presentation/features/profile/profile_page.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

/// AppBar'larda kullanılan profil butonu; Profil sayfasını açar.
class ProfileButton extends StatelessWidget {
  /// Profil butonu.
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Profil',
      icon: const UserAvatar(),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage())),
    );
  }
}

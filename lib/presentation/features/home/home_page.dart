import 'package:e_medrese/presentation/widgets/profile_button.dart';
import 'package:flutter/material.dart';

/// Giriş sonrası ana ekran. Medrese listesi buraya gelecek.
class HomePage extends StatelessWidget {
  /// Ana ekran.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('e-Medrese'),
        actions: const [ProfileButton()],
      ),
      body: const Center(child: Text('Hoş geldin')),
    );
  }
}

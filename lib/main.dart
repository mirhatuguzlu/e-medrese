import 'package:e_medrese/core/constants/supabase_config.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/presentation/features/auth/login_page.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      // Oturum değişince açık sayfa yığını (ör. Profil) sıfırlanır.
      key: ValueKey(session.valueOrNull?.user.id),
      title: 'e-Medrese',
      home: switch (session) {
        AsyncData(value: Session()) => const HomePage(),
        AsyncLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        // Oturum yok ya da yenilenemedi (ör. süresi dolmuş refresh token).
        _ => const LoginPage(),
      },
    );
  }
}

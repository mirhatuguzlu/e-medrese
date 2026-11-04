import 'package:e_medrese/core/constants/supabase_config.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/presentation/features/auth/login_page.dart';
import 'package:e_medrese/presentation/features/shell/main_shell.dart';
import 'package:e_medrese/presentation/features/update/update_required_page.dart';
import 'package:e_medrese/services/update_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ayarlar android/app/google-services.json'dan gelir.
  await Firebase.initializeApp();
  // 2.9'un telefona kaydettiği kurslar sunucuya taşınırken okunur.
  await Hive.initFlutter();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Uygulama arka planda açık kalırken çıkan sürüm de yakalansın.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(updateRequiredProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    // Yeniden kontrol sürerken son sonuç geçerli kalır.
    final updateRequired =
        ref.watch(updateRequiredProvider).valueOrNull ?? false;
    return MaterialApp(
      // Oturum değişince açık sayfa yığını (ör. Profil) sıfırlanır.
      key: ValueKey(session.valueOrNull?.user.id),
      title: 'e-Medrese',
      debugShowCheckedModeBanner: false,
      // Açık sayfaların da üstünü örter; güncellenene kadar kullanılamaz.
      builder: (context, child) =>
          updateRequired ? const UpdateRequiredPage() : child!,
      home: switch (session) {
        AsyncData(value: Session()) => const MainShell(),
        AsyncLoading() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        // Oturum yok ya da yenilenemedi (ör. süresi dolmuş refresh token).
        _ => const LoginPage(),
      },
    );
  }
}

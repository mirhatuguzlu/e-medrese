import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/presentation/features/legal/legal_text_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Giriş ekranı; giriş ve kayıt yalnızca Google hesabıyla yapılır.
/// Aydınlatma metni okunduğu onaylanmadan giriş yapılamaz (KVKK m.10).
class LoginPage extends ConsumerStatefulWidget {
  /// Giriş ekranı.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  bool _noticeRead = false;

  Future<void> _google() async {
    setState(() => _loading = true);
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();

    // Başarılı girişte oturum akışı bu sayfayı ağaçtan kaldırır.
    if (!mounted) return;
    setState(() => _loading = false);
    final message = result.errorOrNull?.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'e-Medrese',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hesabına giriş yap',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Aydınlatma metnini oku'),
                    onPressed: () => context.push(
                      const LegalTextPage(
                        title: 'Aydınlatma metni',
                        asset: privacyNoticeAsset,
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _noticeRead,
                    onChanged: (v) => setState(() => _noticeRead = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kişisel verilerimin işlenmesine ilişkin aydınlatma '
                      'metnini okudum.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading || !_noticeRead ? null : _google,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Google ile devam et'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

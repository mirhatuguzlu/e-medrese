import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Giriş ve kayıt ekranı.
class LoginPage extends ConsumerStatefulWidget {
  /// Giriş ekranı.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);

    final String? message;
    if (_isSignUp) {
      final result = await repo.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      message = switch (result) {
        Ok(value: true) => null,
        Ok() =>
          'Hesabın oluşturuldu. E-postandaki bağlantıyla onayla, '
              'sonra giriş yap.',
        Err(:final error) => error.message,
      };
    } else {
      final result = await repo.signIn(
        email: _email.text,
        password: _password.text,
      );
      message = result.errorOrNull?.message;
    }

    // Başarılı girişte oturum akışı bu sayfayı ağaçtan kaldırır.
    if (!mounted) return;
    setState(() => _loading = false);
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
              child: Form(
                key: _formKey,
                child: AutofillGroup(
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
                        _isSignUp ? 'Yeni hesap oluştur' : 'Hesabına giriş yap',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Ad soyad',
                          ),
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Adını yaz.' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-posta'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : 'Geçerli bir e-posta yaz.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Şifre'),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          if (_isSignUp)
                            AutofillHints.newPassword
                          else
                            AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _loading ? null : _submit(),
                        validator: (v) => (v ?? '').length < 6
                            ? 'Şifre en az 6 karakter olmalı.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isSignUp ? 'Kayıt ol' : 'Giriş yap'),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp
                              ? 'Zaten hesabın var mı? Giriş yap'
                              : 'Hesabın yok mu? Kayıt ol',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

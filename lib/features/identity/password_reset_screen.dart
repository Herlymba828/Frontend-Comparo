import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'data/auth_repository.dart';

/// Forgotten password: the e-mail first, then the e-mailed code with the
/// new password.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = errorText(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
    if (mounted) {
      setState(() => _codeSent = true);
    }
  });

  Future<void> _confirm() => _run(() async {
    await ref
        .read(authRepositoryProvider)
        .confirmPasswordReset(
          email: _email.text,
          code: _code.text,
          newPassword: _password.text,
        );
    if (mounted) {
      showInfo(
        context,
        'Mot de passe modifié. Connectez-vous avec le nouveau mot de passe.',
      );
      context.canPop() ? context.pop() : context.go('/auth');
    }
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpacing.space24),
              children: [
                Text(
                  _codeSent
                      ? 'Si un compte existe pour cette adresse, un code à '
                            '6 chiffres vient d’y être envoyé. Il reste valable '
                            'une heure.'
                      : 'Saisissez l’adresse de votre compte : nous y '
                            'enverrons un code pour choisir un nouveau mot de '
                            'passe.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.space24),
                TextFormField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.isEmpty || !email.contains('@')
                        ? 'Saisissez une adresse e-mail valide.'
                        : null;
                  },
                ),
                if (_codeSent) ..._codeFields(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.space24),
                FilledButton(
                  onPressed: _busy ? null : (_codeSent ? _confirm : _sendCode),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _codeSent
                              ? 'Changer mon mot de passe'
                              : 'Recevoir un code',
                        ),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _codeSent = false;
                            _errorMessage = null;
                            _code.clear();
                          }),
                    child: const Text('Changer d’adresse ou renvoyer un code'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _codeFields() => [
    const SizedBox(height: AppSpacing.space12),
    TextFormField(
      controller: _code,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: 6,
      decoration: const InputDecoration(labelText: 'Code reçu'),
      validator: (value) => RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
          ? null
          : 'Le code contient 6 chiffres.',
    ),
    const SizedBox(height: AppSpacing.space4),
    TextFormField(
      controller: _password,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: 'Nouveau mot de passe',
        suffixIcon: IconButton(
          tooltip: _obscurePassword
              ? 'Afficher le mot de passe'
              : 'Masquer le mot de passe',
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) => (value?.length ?? 0) < 8
          ? 'Le mot de passe doit contenir au moins 8 caractères.'
          : null,
    ),
    const SizedBox(height: AppSpacing.space12),
    TextFormField(
      controller: _passwordConfirm,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
      validator: (value) => value != _password.text
          ? 'Les mots de passe ne correspondent pas.'
          : null,
    ),
  ];
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/auth_providers.dart';
import 'models/auth_user.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUp = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Votre compte')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space24),
            child: auth.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _buildForm(),
              data: (user) =>
                  user == null ? _buildForm() : _buildSignedIn(user),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            _isSignUp ? 'Créer un compte' : 'Connexion',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Connectez-vous pour suivre vos prix et recevoir vos alertes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.space24),
          if (_isSignUp) ...[
            TextFormField(
              controller: _displayNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom affiché'),
            ),
            const SizedBox(height: AppSpacing.space12),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Adresse e-mail'),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty || !email.contains('@')) {
                return 'Saisissez une adresse e-mail valide.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.space12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: [
              _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Saisissez votre mot de passe.';
              }
              if (_isSignUp && (value?.length ?? 0) < 8) {
                return 'Le mot de passe doit contenir au moins 8 caractères.';
              }
              return null;
            },
          ),
          if (_isSignUp) ...[
            const SizedBox(height: AppSpacing.space12),
            TextFormField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas.';
                }
                return null;
              },
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.space12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.space24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isSignUp ? 'Créer mon compte' : 'Se connecter'),
          ),
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                  }),
            child: Text(
              _isSignUp ? 'J’ai déjà un compte' : 'Créer un nouveau compte',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedIn(AuthUser user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.account_circle_outlined,
          size: 56,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.space12),
        Text(
          user.displayName.isEmpty ? user.email : user.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(user.email, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.space24),
        FilledButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          child: const Text('Continuer'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _logout,
          child: const Text('Se déconnecter'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final controller = ref.read(authSessionProvider.notifier);
      if (_isSignUp) {
        await controller.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirm: _passwordConfirmController.text,
          displayName: _displayNameController.text,
        );
      } else {
        await controller.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) {
        context.canPop() ? context.pop() : context.go('/alerts');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).logout();
      if (mounted) {
        setState(() => _isSignUp = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _messageFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _messageFor(Object error) => error is ApiException
      ? error.userMessage
      : 'Une erreur inattendue est survenue. Réessayez.';
}

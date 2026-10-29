import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';
import 'account_repository.dart';

/// Sends a code to the account's address and asks for it; true once the
/// address is verified. A verified address is needed to confirm or contest
/// other people's price reports.
Future<bool> verifyEmailFlow(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(accountRepositoryProvider);
  try {
    await repository.sendEmailCode();
  } catch (error) {
    if (context.mounted) {
      showApiError(context, error, 'Le code n’a pas pu être envoyé.');
    }
    return false;
  }
  if (!context.mounted) {
    return false;
  }
  final verified = await showDialog<bool>(
    context: context,
    builder: (context) => _CodeDialog(repository: repository),
  );
  if (verified ?? false) {
    ref.invalidate(authSessionProvider);
    return true;
  }
  return false;
}

/// True when [error] says the address must be verified first.
bool isEmailNotVerified(Object error) =>
    error is ApiException && error.code == 'email_not_verified';

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.repository});

  final AccountRepository repository;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.confirmEmail(_code.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorText(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resend() async {
    try {
      await widget.repository.sendEmailCode();
      if (mounted) {
        showInfo(context, 'Un nouveau code a été envoyé.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vérifier votre adresse'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saisissez le code à 6 chiffres reçu par e-mail. Il est '
            'valable 2 heures.',
          ),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Code', errorText: _error),
            onSubmitted: (_) => _busy ? null : _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Renvoyer'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

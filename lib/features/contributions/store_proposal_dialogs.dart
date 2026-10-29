import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// What the user is told before their position is sent to map a store.
const storePositionConsent =
    'Votre position actuelle sert à situer ce magasin : soyez à '
    'l’intérieur ou juste devant. Elle est gardée sans lien visible avec '
    'votre compte, le temps que 10 personnes signalent le magasin (90 jours '
    'au plus), puis effacée. Seule la position du magasin est conservée.';

/// A store the user proposes to add.
class StoreProposalDraft {
  const StoreProposalDraft({
    required this.name,
    required this.city,
    required this.street,
  });

  final String name;
  final String city;
  final String street;
}

/// Asks for the missing store's name and place, with the position consent.
Future<StoreProposalDraft?> showProposeStoreDialog(
  BuildContext context, {
  String initialName = '',
}) => showDialog<StoreProposalDraft>(
  context: context,
  builder: (context) => _ProposeStoreDialog(initialName: initialName),
);

/// Asks before the position is used to locate a store that has none.
Future<bool> confirmLocateStore(BuildContext context, String storeName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Aider à localiser ce magasin ?'),
      content: Text(
        '« $storeName » n’a pas encore de position.\n\n$storePositionConsent',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Non merci'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Envoyer ma position'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _ProposeStoreDialog extends StatefulWidget {
  const _ProposeStoreDialog({required this.initialName});

  final String initialName;

  @override
  State<_ProposeStoreDialog> createState() => _ProposeStoreDialogState();
}

class _ProposeStoreDialogState extends State<_ProposeStoreDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _city = TextEditingController();
  final _street = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _city, _street]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _send() {
    if (!_form.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      StoreProposalDraft(
        name: _name.text.trim(),
        city: _city.text.trim(),
        street: _street.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Proposer ce magasin'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Le magasin sera ajouté quand 10 personnes l’auront signalé '
                'au même endroit.',
              ),
              const SizedBox(height: AppSpacing.space12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nom du magasin',
                  hintText: 'ex. Boutique Chez Mama',
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Indiquez le nom du magasin.'
                    : null,
              ),
              TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Ville'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Indiquez la ville.' : null,
              ),
              TextFormField(
                controller: _street,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Quartier ou repère (facultatif)',
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              const Text(
                storePositionConsent,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _send,
          child: const Text('Envoyer ma position'),
        ),
      ],
    );
  }
}

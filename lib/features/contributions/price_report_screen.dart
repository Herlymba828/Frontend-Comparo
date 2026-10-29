import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../account/account_repository.dart';
import 'price_input.dart';
import 'price_report_repository.dart';
import 'report_store_step.dart';

/// Report a price seen on a shelf: store, product, price, optional photo.
class PriceReportScreen extends StatelessWidget {
  const PriceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relever un prix')),
      body: SignedInGate(
        signInMessage: 'Connectez-vous pour relever un prix.',
        builder: (user) => const PriceReportForm(),
      ),
    );
  }
}

class PriceReportForm extends ConsumerStatefulWidget {
  const PriceReportForm({super.key});

  @override
  ConsumerState<PriceReportForm> createState() => _PriceReportFormState();
}

class _PriceReportFormState extends ConsumerState<PriceReportForm> {
  final _form = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _notes = TextEditingController();
  final _productFocus = FocusNode();
  final _priceFocus = FocusNode();
  Timer? _productDebounce;
  Timer? _checkDebounce;

  StoreChoice? _store;
  ProductSuggestion? _picked;
  List<ProductSuggestion> _suggestions = const [];
  String? _unit;
  bool _unitTouched = false;
  PriceCheck? _check;
  PhotoAttachment? _photo;
  bool _displayError = false;
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _productDebounce?.cancel();
    _checkDebounce?.cancel();
    for (final controller in [_product, _price, _quantity, _notes]) {
      controller.dispose();
    }
    _productFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  // ── Product ───────────────────────────────────────────────────────────
  void _onProductChanged(String text) {
    if (_picked != null && text != _picked!.name) {
      setState(() {
        _picked = null;
        _check = null;
      });
    }
    _productDebounce?.cancel();
    final query = text.trim();
    if (query.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _productDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _suggest(query),
    );
  }

  Future<void> _suggest(String query) async {
    try {
      final found = await ref
          .read(priceReportRepositoryProvider)
          .searchProducts(query);
      if (mounted && _product.text.trim() == query && _picked == null) {
        setState(() => _suggestions = found);
      }
    } on ApiException {
      // Suggestions are a help: a new name can still be typed.
    }
  }

  Future<void> _pick(ProductSuggestion product) async {
    setState(() {
      _picked = product;
      _product.text = product.name;
      _suggestions = const [];
    });
    _priceFocus.requestFocus();
    await _runCheck(prefill: true);
  }

  // ── Price check ──────────────────────────────────────────────────────
  void _scheduleCheck() {
    _checkDebounce?.cancel();
    _checkDebounce = Timer(const Duration(milliseconds: 400), _runCheck);
  }

  Future<void> _runCheck({bool prefill = false}) async {
    final product = _picked;
    if (product == null) {
      return;
    }
    final price = parseObservedPrice(_price.text);
    try {
      final check = await ref
          .read(priceReportRepositoryProvider)
          .priceCheck(
            productId: product.id,
            price: price.value,
            quantity: parseQuantity(_quantity.text),
            unitCode: _unit,
          );
      if (!mounted || _picked?.id != product.id) {
        return;
      }
      setState(() {
        _check = check;
        // Pre-fill the usual format of the product, unless already chosen.
        if (prefill && !_unitTouched && check.typicalUnit.isNotEmpty) {
          _unit = check.typicalUnit;
          _quantity.text = formatQuantity(check.typicalQuantity ?? '1');
        }
      });
    } on ApiException {
      // The check only warns; the server validates again on submit.
    }
  }

  // ── Photo ────────────────────────────────────────────────────────────
  Future<void> _takePhoto({required bool fromCamera}) async {
    try {
      final photo = await ref
          .read(photoPickerProvider)
          .pick(fromCamera: fromCamera);
      if (photo != null && mounted) {
        setState(() => _photo = photo);
      }
    } on PhotoRejected catch (error) {
      if (mounted) {
        showInfo(context, error.message);
      }
    } on Exception {
      if (mounted) {
        showInfo(context, 'Impossible d’accéder à l’appareil photo.');
      }
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _submitted = true);
    final store = _store;
    if (store == null) {
      showInfo(context, 'Choisissez d’abord le magasin.');
      return;
    }
    if (!_form.currentState!.validate()) {
      return;
    }
    final draft = PriceReportDraft(
      store: store.store,
      locationMethod: store.method,
      position: store.position,
      productId: _picked?.id,
      productName: _product.text.trim(),
      price: parseObservedPrice(_price.text).value!,
      quantity: parseQuantity(_quantity.text)!,
      unitCode: _unit ?? '',
      photo: _photo,
      displayError: _displayError,
      notes: _displayError ? _notes.text.trim() : '',
    );
    if (_check?.isOutlier == true && !await _confirmUnusual(_check!)) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _send(_check?.isOutlier == true ? draft.confirmed() : draft);
  }

  Future<void> _send(PriceReportDraft draft) async {
    setState(() => _saving = true);
    Exception? failure;
    try {
      await ref.read(priceReportRepositoryProvider).submit(draft);
      ref.invalidate(contributionsProvider(false));
    } on Exception catch (error) {
      failure = error;
    }
    if (!mounted) {
      return;
    }
    // Stop the progress indicator before any dialog opens.
    setState(() => _saving = false);
    switch (failure) {
      case null:
        _resetAfterSuccess();
      case UnusualPriceException(:final check):
        if (await _confirmUnusual(check) && mounted) {
          await _send(draft.confirmed());
        }
      case DuplicateReportException():
        await _showDuplicate(failure);
      default:
        showApiError(context, failure, 'Relevé non enregistré.');
    }
  }

  void _resetAfterSuccess() {
    // Reset first: it empties the fields, then the defaults are set again.
    _form.currentState?.reset();
    setState(() {
      _picked = null;
      _check = null;
      _photo = null;
      _displayError = false;
      _submitted = false;
      _unit = null;
      _unitTouched = false;
    });
    _product.clear();
    _price.clear();
    _notes.clear();
    _quantity.text = '1';
    _productFocus.requestFocus();
    showInfo(
      context,
      'Relevé enregistré, merci ! Il sera publié après vérification. '
      'Vous pouvez relever un autre prix dans ce magasin.',
    );
  }

  Future<bool> _confirmUnusual(PriceCheck check) async {
    final usual = check.medianUnitPrice == null
        ? ''
        : ' Les relevés récents tournent autour de '
              '${formatUnitPrice(check.medianUnitPrice, 'XAF')}'
              '${check.baseUnit.isEmpty ? '' : ' / ${check.baseUnit}'}.';
    return confirmAction(
      context,
      title: 'Prix inhabituel',
      message:
          'Ce prix est très éloigné des prix connus.$usual '
          'Confirmez-vous le prix de l’étiquette ?',
      confirmLabel: 'Oui, c’est le bon prix',
    );
  }

  Future<void> _showDuplicate(
    DuplicateReportException error,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Déjà relevé ces dernières 24 h'),
      content: Text(
        '${error.message}\n\n'
        '${error.isMine ? 'Vous avez déjà relevé ce produit dans ce magasin : un seul relevé par jour suffit.' : 'S’il attend encore sa vérification, confirmez-le dans « À vérifier » si vous voyez le même prix ; un prix différent est accepté comme contestation.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fermer'),
        ),
        if (!error.isMine)
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/contributions');
            },
            child: const Text('Voir les relevés à vérifier'),
          ),
      ],
    ),
  );

  // ── Layout ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            children: [
              _Section(
                number: 1,
                title: 'Magasin',
                child: ReportStoreStep(
                  choice: _store,
                  onChanged: (choice) => setState(() => _store = choice),
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              _Section(
                number: 2,
                title: 'Produit et prix',
                child: _productAndPrice(context),
              ),
              const SizedBox(height: AppSpacing.space16),
              _Section(
                number: 3,
                title: 'Vérification (facultatif)',
                child: _evidence(context),
              ),
              const SizedBox(height: AppSpacing.space24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Envoi…' : 'Enregistrer le relevé'),
              ),
              const SizedBox(height: AppSpacing.space8),
              const Text(
                'Votre relevé est horodaté automatiquement et publié sous '
                'un pseudonyme après confirmation par d’autres personnes.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productAndPrice(BuildContext context) {
    final units = ref.watch(reportUnitsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _product,
          focusNode: _productFocus,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Produit (nom complet, marque, format)',
            hintText: 'ex. Riz parfumé Tilda 1 kg',
            prefixIcon: const Icon(Icons.inventory_2_outlined),
            helperText: _picked != null
                ? 'Produit du catalogue'
                : (_product.text.trim().length >= 2 && _suggestions.isEmpty
                      ? 'Nouveau produit : il sera vérifié'
                      : null),
          ),
          validator: (value) => (value ?? '').trim().length < 2
              ? 'Indiquez le nom du produit.'
              : null,
          onChanged: _onProductChanged,
          onFieldSubmitted: (_) => _priceFocus.requestFocus(),
        ),
        if (_suggestions.isNotEmpty)
          Semantics(
            container: true,
            label: '${_suggestions.length} produits suggérés',
            child: Column(
              children: [
                for (final suggestion in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.north_west, size: 18),
                    title: Text(suggestion.name),
                    onTap: () => _pick(suggestion),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.space12),
        TextFormField(
          controller: _price,
          focusNode: _priceFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9 .,  ]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Prix affiché',
            hintText: 'ex. 1 500',
            suffixText: 'XAF',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
          validator: (value) => parseObservedPrice(value ?? '').error,
          onChanged: (_) => _scheduleCheck(),
        ),
        const SizedBox(height: AppSpacing.space12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantité'),
                validator: (value) => parseQuantity(value ?? '') == null
                    ? 'Nombre positif.'
                    : null,
                onChanged: (_) => _scheduleCheck(),
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: units.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => const Text(
                  'Unités indisponibles',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                data: (options) => DropdownButtonFormField<String>(
                  initialValue: options.any((unit) => unit.code == _unit)
                      ? _unit
                      : null,
                  key: ValueKey(_unit),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unité'),
                  items: [
                    for (final unit in options)
                      DropdownMenuItem(
                        value: unit.code,
                        child: Text(
                          unit.symbol.isEmpty ? unit.name : unit.symbol,
                        ),
                      ),
                  ],
                  validator: (value) => options.isNotEmpty && value == null
                      ? 'Choisissez l’unité.'
                      : null,
                  onChanged: (value) {
                    setState(() {
                      _unit = value;
                      _unitTouched = true;
                    });
                    _scheduleCheck();
                  },
                ),
              ),
            ),
          ],
        ),
        if (_check != null) _PriceHint(check: _check!),
      ],
    );
  }

  Widget _evidence(BuildContext context) {
    final photo = _photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo == null)
          Wrap(
            spacing: AppSpacing.space8,
            runSpacing: AppSpacing.space8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _takePhoto(fromCamera: true),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photographier l’étiquette'),
              ),
              TextButton.icon(
                onPressed: () => _takePhoto(fromCamera: false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choisir une photo'),
              ),
            ],
          )
        else
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  photo.bytes,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  semanticLabel: 'Photo de l’étiquette jointe',
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              const Expanded(
                child: Text('Photo jointe, sans données de localisation.'),
              ),
              IconButton(
                tooltip: 'Retirer la photo',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _photo = null),
              ),
            ],
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _displayError,
          onChanged: (value) => setState(() => _displayError = value ?? false),
          title: const Text('Signaler une erreur d’affichage'),
          subtitle: const Text(
            'Étiquette périmée, prix différent en caisse, mauvais produit…',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_displayError)
          TextFormField(
            controller: _notes,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Précisez (facultatif)',
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MarketSurface(
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            container: true,
            child: Text(
              '$number. $title',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          child,
        ],
      ),
    );
  }
}

/// What the known prices say about the typed one.
class _PriceHint extends StatelessWidget {
  const _PriceHint({required this.check});

  final PriceCheck check;

  @override
  Widget build(BuildContext context) {
    final median = check.medianUnitPrice;
    if (median == null) {
      return const SizedBox.shrink();
    }
    final usual =
        '${formatUnitPrice(median, 'XAF')}'
        '${check.baseUnit.isEmpty ? '' : ' / ${check.baseUnit}'}';
    final unusual = check.isOutlier;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.space8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unusual ? Icons.warning_amber_rounded : Icons.info_outline,
              color: unusual ? AppColors.warning : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text(
                unusual
                    ? 'Prix inhabituel : les relevés récents tournent autour '
                          'de $usual. Vérifiez l’étiquette.'
                    : 'Prix habituel : environ $usual.',
                style: TextStyle(
                  color: unusual ? AppColors.warning : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

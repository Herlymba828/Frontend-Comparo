import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../stores/stores_repository.dart';
import 'price_report_repository.dart';
import 'store_proposal_dialogs.dart';

/// A position less precise than this cannot place a store (as the API).
const _maxSightingAccuracyM = 100;

/// The store chosen for a report, and how it was found.
class StoreChoice {
  const StoreChoice(this.store, this.method, [this.position]);

  final ReportStore store;
  final LocationMethod method;

  /// The device position, only for [LocationMethod.gps]; never stored.
  final UserPosition? position;
}

enum _Stage { checking, consent, locating, nearby, search }

/// Step 1 of a price report: find the store the user stands in.
///
/// The position is only read after an explicit choice (or when the system
/// permission was already granted), and searching by name is always offered.
class ReportStoreStep extends ConsumerStatefulWidget {
  const ReportStoreStep({
    super.key,
    required this.choice,
    required this.onChanged,
  });

  final StoreChoice? choice;
  final ValueChanged<StoreChoice?> onChanged;

  @override
  ConsumerState<ReportStoreStep> createState() => _ReportStoreStepState();
}

class _ReportStoreStepState extends ConsumerState<ReportStoreStep> {
  final _search = TextEditingController();
  Timer? _debounce;
  _Stage _stage = _Stage.checking;
  String? _message;
  UserPosition? _position;
  List<ReportStore> _nearby = const [];
  List<ReportStore> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Permission already granted in the system settings: no second prompt.
    final granted = await ref.read(positionServiceProvider).isGranted();
    if (!mounted) {
      return;
    }
    if (granted) {
      await _locate();
    } else {
      setState(() => _stage = _Stage.consent);
    }
  }

  void _manual(String? message) {
    setState(() {
      _stage = _Stage.search;
      _message = message;
    });
  }

  Future<void> _locate() async {
    setState(() {
      _stage = _Stage.locating;
      _message = null;
    });
    final position = await ref.read(positionServiceProvider).locate();
    if (!mounted) {
      return;
    }
    if (!position.isKnown) {
      _manual(
        position.isDenied
            ? 'Localisation refusée : recherchez le magasin par son nom.'
            : '${position.problem ?? 'Position introuvable.'} '
                  'Recherchez le magasin par son nom.',
      );
      return;
    }
    try {
      final stores = await ref
          .read(priceReportRepositoryProvider)
          .nearbyStores(position);
      if (!mounted) {
        return;
      }
      _position = position;
      if (stores.isEmpty) {
        _manual(
          'Aucun magasin référencé à moins de 500 m. '
          'Recherchez-le par son nom.',
        );
      } else if (stores.length == 1) {
        _nearby = stores;
        setState(() => _stage = _Stage.nearby);
        widget.onChanged(
          StoreChoice(stores.single, LocationMethod.gps, position),
        );
      } else {
        setState(() {
          _nearby = stores;
          _stage = _Stage.nearby;
        });
      }
    } on ApiException catch (error) {
      final accuracy = error.fields?['accuracy_m'];
      _manual(
        accuracy is List && accuracy.isNotEmpty
            ? accuracy.first.toString()
            : errorText(error, 'Impossible de chercher les magasins proches.'),
      );
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _find(query));
  }

  Future<void> _find(String query) async {
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(priceReportRepositoryProvider)
          .searchStores(query);
      if (mounted && _search.text.trim() == query) {
        setState(() => _results = results);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showApiError(context, error, 'Recherche impossible.');
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _showPrivacy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Votre position et vos droits'),
      content: const SingleChildScrollView(
        child: Text(
          '• But : trouver les magasins référencés à moins de 500 m de vous, '
          'pour rattacher votre relevé au bon magasin.\n'
          '• Base : votre consentement. Vous pouvez le retirer à tout moment '
          'dans les réglages de votre appareil, et toujours choisir le '
          'magasin à la main.\n'
          '• Conservation : votre position n’est pas enregistrée. Seule la '
          'distance entre vous et le magasin est gardée avec le relevé.\n'
          '• Exception, toujours sur votre accord : pour localiser ou '
          'proposer un magasin, votre position est gardée sans lien visible '
          'avec votre compte jusqu’à la décision (90 jours au plus), puis '
          'effacée.\n'
          '• Partage : vos données ne sont ni vendues ni partagées. Les autres '
          'utilisateurs voient votre relevé sous un pseudonyme.\n'
          '• Vos droits : accès, rectification et suppression de vos relevés '
          'depuis l’assistance de l’application.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Compris'),
        ),
      ],
    ),
  );

  // ── Community mapping: locate a store, propose a missing one ───────────
  final _helpedLocate = <int>{};
  bool _sharing = false;

  /// Reads the position for a store sighting; null (with a message) when it
  /// cannot place a store.
  Future<UserPosition?> _sightingPosition() async {
    final position = await ref.read(positionServiceProvider).locate();
    if (!mounted) {
      return null;
    }
    if (!position.isKnown) {
      showInfo(
        context,
        position.isDenied
            ? 'Localisation refusée : impossible de situer le magasin.'
            : 'Position introuvable pour le moment : réessayez dehors.',
      );
      return null;
    }
    final accuracy = position.accuracyM ?? 0;
    if (accuracy > _maxSightingAccuracyM) {
      showInfo(
        context,
        'Position trop imprécise (± ${accuracy.round()} m) : réessayez '
        'devant le magasin.',
      );
      return null;
    }
    return position;
  }

  Future<void> _share(
    Future<StoreProposalResult> Function(UserPosition position) send, {
    required void Function(StoreProposalResult result, UserPosition position)
    onDone,
  }) async {
    setState(() => _sharing = true);
    try {
      final position = await _sightingPosition();
      if (position == null) {
        return;
      }
      final result = await send(position);
      if (mounted) {
        onDone(result, position);
      }
    } on StoreProposalConflict catch (conflict) {
      if (!mounted) {
        return;
      }
      final existing = conflict.existingStore;
      if (existing != null) {
        widget.onChanged(StoreChoice(existing, LocationMethod.manual));
        showInfo(context, 'Ce magasin est déjà référencé : il est choisi.');
      } else {
        showInfo(context, conflict.message);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showApiError(context, error, 'Signalement non envoyé.');
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  Future<void> _proposeStore() async {
    final draft = await showProposeStoreDialog(
      context,
      initialName: _search.text.trim(),
    );
    if (draft == null || !mounted) {
      return;
    }
    await _share(
      (position) => ref
          .read(priceReportRepositoryProvider)
          .proposeStore(
            name: draft.name,
            city: draft.city,
            street: draft.street,
            position: position,
          ),
      onDone: (result, position) {
        final store = result.store;
        if (result.isDecided && store != null) {
          widget.onChanged(StoreChoice(store, LocationMethod.gps, position));
          showInfo(
            context,
            'Magasin ajouté : vous pouvez y relever des prix. Merci !',
          );
        } else {
          showInfo(
            context,
            'Merci ! Magasin signalé par ${result.sightings} personne(s) '
            'sur ${result.required}.',
          );
        }
      },
    );
  }

  Future<void> _locateStore(ReportStore store) async {
    if (!await confirmLocateStore(context, store.name) || !mounted) {
      return;
    }
    await _share(
      (position) => ref
          .read(priceReportRepositoryProvider)
          .locateStore(store.id, position),
      onDone: (result, position) {
        setState(() => _helpedLocate.add(store.id));
        showInfo(
          context,
          result.isDecided
              ? 'Merci ! Ce magasin est maintenant localisé.'
              : 'Merci ! Position enregistrée (${result.sightings} sur '
                    '${result.required}).',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final choice = widget.choice;
    if (choice != null) {
      final store = choice.store;
      return _ChosenStore(
        choice: choice,
        onLocate: store.hasCoordinates || _helpedLocate.contains(store.id)
            ? null
            : (_sharing ? () {} : () => _locateStore(store)),
        onChange: () {
          widget.onChanged(null);
          setState(
            () => _stage = _nearby.length > 1 ? _Stage.nearby : _Stage.search,
          );
        },
      );
    }
    return switch (_stage) {
      _Stage.checking ||
      _Stage.locating => const _Busy('Recherche des magasins autour de vous…'),
      _Stage.consent => _Consent(
        onLocate: _locate,
        onManual: () => _manual(null),
        onPrivacy: _showPrivacy,
      ),
      _Stage.nearby => _StoreList(
        title: 'Magasins à moins de 500 m',
        stores: _nearby,
        onTap: (store) =>
            widget.onChanged(StoreChoice(store, LocationMethod.gps, _position)),
        footer: TextButton(
          onPressed: () => _manual(null),
          child: const Text('Mon magasin n’est pas dans la liste'),
        ),
      ),
      _Stage.search => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                child: Text(
                  _message!,
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            ),
          TextField(
            controller: _search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Rechercher le magasin',
              hintText: 'Nom, enseigne, quartier ou ville',
              prefixIcon: const Icon(Icons.storefront_outlined),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.space12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
          if (_search.text.trim().length >= 2 &&
              !_searching &&
              _results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.space8),
              child: Text('Aucun magasin trouvé.'),
            ),
          if (_results.isNotEmpty)
            _StoreList(
              stores: _results,
              onTap: (store) =>
                  widget.onChanged(StoreChoice(store, LocationMethod.manual)),
            ),
          TextButton.icon(
            onPressed: _sharing ? null : _proposeStore,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Mon magasin n’est pas référencé'),
          ),
          if (_position == null)
            TextButton.icon(
              onPressed: _locate,
              icon: const Icon(Icons.my_location),
              label: const Text('Utiliser ma position'),
            ),
        ],
      ),
    };
  }
}

class _Busy extends StatelessWidget {
  const _Busy(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(width: AppSpacing.space12),
        Expanded(child: ExcludeSemantics(child: Text(label))),
      ],
    ),
  );
}

class _Consent extends StatelessWidget {
  const _Consent({
    required this.onLocate,
    required this.onManual,
    required this.onPrivacy,
  });

  final VoidCallback onLocate;
  final VoidCallback onManual;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pour retrouver le magasin, l’application peut lire votre position '
          'une seule fois. Elle n’est ni conservée, ni vendue, ni partagée : '
          'seule la distance au magasin est enregistrée.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onPrivacy,
            child: const Text('Vos données et vos droits'),
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        FilledButton.icon(
          onPressed: onLocate,
          icon: const Icon(Icons.my_location),
          label: const Text('Utiliser ma position'),
        ),
        const SizedBox(height: AppSpacing.space8),
        OutlinedButton.icon(
          onPressed: onManual,
          icon: const Icon(Icons.search),
          label: const Text('Choisir le magasin moi-même'),
        ),
      ],
    );
  }
}

class _StoreList extends StatelessWidget {
  const _StoreList({
    required this.stores,
    required this.onTap,
    this.title,
    this.footer,
  });

  final List<ReportStore> stores;
  final ValueChanged<ReportStore> onTap;
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(title!, style: Theme.of(context).textTheme.labelLarge),
        for (final store in stores)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: Text(store.merchantName),
            subtitle: Text(
              [
                store.name,
                if (store.address.isNotEmpty) store.address,
              ].join(' · '),
            ),
            trailing: store.distanceM == null
                ? null
                : Text('${store.distanceM} m'),
            onTap: () => onTap(store),
          ),
        ?footer,
      ],
    );
  }
}

class _ChosenStore extends StatelessWidget {
  const _ChosenStore({
    required this.choice,
    required this.onChange,
    this.onLocate,
  });

  final StoreChoice choice;
  final VoidCallback onChange;

  /// Set while the store has no position the user could help find.
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    final store = choice.store;
    final distance = store.distanceM;
    final summary = Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.primary),
        const SizedBox(width: AppSpacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.merchantName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                [
                  store.name,
                  if (distance != null) 'à $distance m de vous',
                ].join(' · '),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onChange,
          child: Text('Changer', semanticsLabel: 'Changer de magasin'),
        ),
      ],
    );
    final locate = onLocate;
    if (locate == null) {
      return summary;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summary,
        const SizedBox(height: AppSpacing.space8),
        const Text(
          'Ce magasin n’a pas encore de position sur la carte.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: locate,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Aider à le localiser'),
          ),
        ),
      ],
    );
  }
}

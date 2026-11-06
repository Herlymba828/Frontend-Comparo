import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters/price_formatter.dart';
import '../../core/json/named_ref.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/market_widgets.dart';
import '../catalog/product_picker_field.dart';
import 'budget_repository.dart';

String _money(String amount) =>
    amount.isEmpty ? 'Indisponible' : formatPrice(amount, 'XAF');

String _day(DateTime? value) => formatDateTime(value).split(' ').first;

/// The user's shopping budgets (PJ-031).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await showBudgetEditor(context);
          if (saved != null && context.mounted) {
            ref.invalidate(budgetsProvider);
            context.push('/account/budgets/${saved.id}');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouveau budget'),
      ),
      body: SignedInGate(
        signInMessage: 'Connectez-vous pour préparer vos budgets.',
        builder: (user) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(budgetsProvider),
          child: AsyncBody<List<Budget>>(
            value: ref.watch(budgetsProvider),
            onRetry: () => ref.invalidate(budgetsProvider),
            builder: (budgets) => budgets.isEmpty
                ? const EmptyState(
                    icon: Icons.savings_outlined,
                    title: 'Aucun budget pour le moment.',
                    message:
                        'Listez vos achats prévus : nous estimons leur coût '
                        'aujourd’hui, d’après les prix récents et la prévision.',
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    itemCount: budgets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.space8),
                    itemBuilder: (context, index) {
                      final budget = budgets[index];
                      return MarketSurface(
                        onTap: () =>
                            context.push('/account/budgets/${budget.id}'),
                        padding: const EdgeInsets.all(AppSpacing.space12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    budget.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    '${budget.lines.length} produit(s)'
                                    '${budget.plannedFor == null ? '' : ' · pour le ${_day(budget.plannedFor)}'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(_money(budget.currentTotal)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// A budget and its estimate, each kind of cost on its own line.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key, required this.budgetId});

  final int budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = budgetProvider(budgetId);
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: SignedInGate(
        builder: (user) => AsyncBody<Budget>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (budget) => ListView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            children: [
              SectionCard(
                title: budget.name,
                children: [
                  if (budget.plannedFor != null)
                    InfoRow('Achat prévu', _day(budget.plannedFor)),
                  InfoRow('Au prix actuel', _money(budget.currentTotal)),
                  InfoRow(
                    'Moyenne des 30 derniers jours',
                    _money(budget.recentAverageTotal),
                  ),
                  InfoRow('Prévision', _money(budget.forecastTotal)),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    budget.limits,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space12),
              for (final line in budget.lines) ...[
                SectionCard(
                  title: line.productName,
                  trailing: Text(
                    '${formatQuantity(line.quantity)} ${line.unit}'.trim(),
                  ),
                  children: [
                    InfoRow('Prix actuel', _money(line.currentTotal)),
                    InfoRow(
                      'Moyenne récente',
                      line.recentAverageTotal.isEmpty
                          ? 'Indisponible'
                          : '${_money(line.recentAverageTotal)} '
                                '(${line.recentSamples} prix)',
                    ),
                    InfoRow(
                      'Prévision',
                      line.forecast == null
                          ? 'Indisponible'
                          : '${_money(line.forecast!.total)}, entre '
                                '${_money(line.forecast!.lower)} et '
                                '${_money(line.forecast!.upper)}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final saved = await showBudgetEditor(
                          context,
                          budget: budget,
                        );
                        if (saved != null) {
                          ref
                            ..invalidate(provider)
                            ..invalidate(budgetsProvider);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Supprimer ce budget ?',
                          message:
                              'La liste et son estimation seront effacées.',
                          confirmLabel: 'Supprimer',
                        );
                        if (!ok || !context.mounted) {
                          return;
                        }
                        try {
                          await ref
                              .read(budgetRepositoryProvider)
                              .delete(budget.id);
                          ref.invalidate(budgetsProvider);
                          if (context.mounted) {
                            context.pop();
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showApiError(context, error);
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates or edits a budget; returns the saved budget, null when cancelled.
Future<Budget?> showBudgetEditor(BuildContext context, {Budget? budget}) =>
    showDialog<Budget>(
      context: context,
      builder: (context) => _BudgetEditor(budget: budget),
    );

class _EditableLine {
  _EditableLine(this.product, String quantity)
    : quantity = TextEditingController(text: quantity);

  NamedRef? product;
  final TextEditingController quantity;
}

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({this.budget});

  final Budget? budget;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  late final _name = TextEditingController(
    text: widget.budget?.name ?? 'Courses du mois',
  );
  late DateTime? _plannedFor = widget.budget?.plannedFor;
  late final List<_EditableLine> _lines = [
    for (final line in widget.budget?.lines ?? const <BudgetLine>[])
      _EditableLine(NamedRef(line.productId, line.productName), line.quantity),
    if (widget.budget == null) _EditableLine(null, '1'),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    for (final line in _lines) {
      line.quantity.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final items = [
      for (final line in _lines)
        if (line.product != null)
          (
            productId: line.product!.id,
            quantity: line.quantity.text.trim().replaceAll(',', '.'),
          ),
    ];
    if (_name.text.trim().isEmpty || items.isEmpty) {
      showInfo(context, 'Donnez un nom et choisissez au moins un produit.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      final budget = widget.budget;
      final saved = budget == null
          ? await repo.create(
              name: _name.text.trim(),
              plannedFor: _plannedFor,
              items: items,
            )
          : await repo.update(
              budget.id,
              name: _name.text.trim(),
              plannedFor: _plannedFor,
              items: items,
            );
      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.budget == null ? 'Nouveau budget' : 'Modifier'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _plannedFor == null
                      ? 'Date d’achat (facultatif)'
                      : 'Achat prévu le ${_day(_plannedFor)}',
                ),
                trailing: _plannedFor == null
                    ? null
                    : IconButton(
                        tooltip: 'Retirer la date',
                        onPressed: () => setState(() => _plannedFor = null),
                        icon: const Icon(Icons.close),
                      ),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 90)),
                    initialDate: _plannedFor ?? now,
                  );
                  if (picked != null) {
                    setState(() => _plannedFor = picked);
                  }
                },
              ),
              const Divider(),
              for (final line in _lines)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ProductPickerField(
                        value: line.product,
                        onChanged: (product) =>
                            setState(() => line.product = product),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space8),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: line.quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Qté'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Retirer',
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.remove(line)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _lines.add(_EditableLine(null, '1'))),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un produit'),
              ),
              Text(
                'Quantité dans l’unité de comparaison du produit (kg, L ou pièce).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

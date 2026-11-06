import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';

class BudgetForecast {
  const BudgetForecast({
    required this.date,
    required this.total,
    required this.lower,
    required this.upper,
  });

  final DateTime? date;
  final String total;
  final String lower;
  final String upper;

  factory BudgetForecast.fromJson(Map<String, dynamic> json) => BudgetForecast(
    date: json.dateOrNull('date'),
    total: json.string('total'),
    lower: json.string('lower'),
    upper: json.string('upper'),
  );
}

/// One product of a budget: current, recent and forecast costs kept apart.
class BudgetLine {
  const BudgetLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.currentTotal,
    required this.recentAverageTotal,
    required this.recentSamples,
    required this.forecast,
  });

  final int productId;
  final String productName;
  final String quantity;
  final String unit;

  /// Empty when no offer is on sale now.
  final String currentTotal;
  final String recentAverageTotal;
  final int recentSamples;
  final BudgetForecast? forecast;

  factory BudgetLine.fromJson(Map<String, dynamic> json) {
    final forecast = json.mapOrNull('forecast');
    return BudgetLine(
      productId: json.requireInt('product'),
      productName: json.string('product_name'),
      quantity: json.string('quantity', '1'),
      unit: json.string('unit'),
      currentTotal: json.string('current_total'),
      recentAverageTotal: json.string('recent_average_total'),
      recentSamples: json.intOrNull('recent_samples') ?? 0,
      forecast: forecast == null ? null : BudgetForecast.fromJson(forecast),
    );
  }
}

class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.plannedFor,
    required this.lines,
    required this.currentTotal,
    required this.recentAverageTotal,
    required this.forecastTotal,
    required this.limits,
  });

  final int id;
  final String name;
  final DateTime? plannedFor;
  final List<BudgetLine> lines;

  /// Empty when a product lacks the value: a partial total would mislead.
  final String currentTotal;
  final String recentAverageTotal;
  final String forecastTotal;
  final String limits;

  factory Budget.fromJson(Map<String, dynamic> json) {
    final estimate = json.mapOrNull('estimate') ?? const {};
    return Budget(
      id: json.requireInt('id'),
      name: json.string('name'),
      plannedFor: json.dateOrNull('planned_for'),
      lines: estimate.maps('items').map(BudgetLine.fromJson).toList(),
      currentTotal: estimate.string('current_total'),
      recentAverageTotal: estimate.string('recent_average_total'),
      forecastTotal: estimate.string('forecast_total'),
      limits: estimate.string('limits'),
    );
  }
}

typedef BudgetItemInput = ({int productId, String quantity});

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(jsonApiProvider)),
);

final budgetsProvider = FutureProvider.autoDispose<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).getBudgets(),
);

final budgetProvider = FutureProvider.autoDispose.family<Budget, int>(
  (ref, id) => ref.watch(budgetRepositoryProvider).getBudget(id),
);

class BudgetRepository {
  const BudgetRepository(this._api);

  final JsonApi _api;

  Future<List<Budget>> getBudgets() async =>
      await _api.getAll('api/analytics/budgets/', Budget.fromJson);

  Future<Budget> getBudget(int id) =>
      _api.getOne('api/analytics/budgets/$id/', Budget.fromJson);

  Map<String, Object?> _payload(
    String name,
    DateTime? plannedFor,
    List<BudgetItemInput> items,
  ) => {
    'name': name,
    'planned_for': plannedFor?.toIso8601String().split('T').first,
    'items': [
      for (final item in items)
        {'product_id': item.productId, 'quantity': item.quantity},
    ],
  };

  Future<Budget> create({
    required String name,
    DateTime? plannedFor,
    required List<BudgetItemInput> items,
  }) => _api.post(
    'api/analytics/budgets/',
    Budget.fromJson,
    data: _payload(name, plannedFor, items),
  );

  Future<Budget> update(
    int id, {
    required String name,
    DateTime? plannedFor,
    required List<BudgetItemInput> items,
  }) => _api.patch(
    'api/analytics/budgets/$id/',
    Budget.fromJson,
    data: _payload(name, plannedFor, items),
    clearable: const {'planned_for'},
  );

  Future<void> delete(int id) => _api.delete('api/analytics/budgets/$id/');
}

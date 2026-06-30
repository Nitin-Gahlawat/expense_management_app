import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../models/expense_model.dart';
import '../models/expense_category.dart';
import '../core/errors.dart';

part 'expense_provider.g.dart';

const String _expenseBoxName = 'expenses';

class ExpenseState {
  final List<ExpenseModel> expenses;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const ExpenseState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  ExpenseState copyWith({
    List<ExpenseModel>? expenses,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get isEmpty => expenses.isEmpty;

  bool get isNotEmpty => expenses.isNotEmpty;

  double get totalAmount => expenses.totalAmount;

  List<ExpenseModel> get sortedByDateDesc => expenses.sortedByDateDesc();

  List<ExpenseModel> get todayExpenses => expenses.today;

  List<ExpenseModel> get thisWeekExpenses => expenses.thisWeek;

  List<ExpenseModel> get thisMonthExpenses => expenses.thisMonth;
}

@riverpod
class ExpenseNotifier extends _$ExpenseNotifier {
  late final Logger _logger;
  Box<ExpenseModel>? _box;

  @override
  Future<ExpenseState> build() async {
    _logger = Logger();
    _logger.i('Building ExpenseNotifier');

    try {
      if (!Hive.isBoxOpen(_expenseBoxName)) {
        _box = await Hive.openBox<ExpenseModel>(_expenseBoxName);
        _logger.i('Expense box opened successfully');
      } else {
        _box = Hive.box<ExpenseModel>(_expenseBoxName);
        _logger.i('Expense box already open');
      }

      final expenses = _loadExpenses();

      _logger.i('ExpenseNotifier built with ${expenses.length} expenses');

      return ExpenseState(expenses: expenses, lastUpdated: DateTime.now());
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to build ExpenseNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  List<ExpenseModel> _loadExpenses() {
    if (_box == null) {
      _logger.w('Expense box is null, returning empty list');
      return [];
    }

    try {
      final expenses = _box!.values.toList();
      _logger.d('Loaded ${expenses.length} expenses from Hive');
      return expenses;
    } catch (e, stackTrace) {
      _logger.e('Failed to load expenses', error: e, stackTrace: stackTrace);
      throw DatabaseException.readFailed(
        key: 'all expenses',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ExpenseModel> addExpense(ExpenseModel expense) async {
    try {
      _logger.i(
        'Adding expense: ${expense.merchantName} - \$${expense.amount}',
      );

      if (_box == null) {
        throw DatabaseException.writeFailed(
          operation: 'add expense',
          error: 'Expense box is not initialized',
        );
      }

      final validationErrors = expense.validate();
      if (validationErrors.isNotEmpty) {
        throw ValidationException(
          'Expense validation failed: ${validationErrors.join(", ")}',
        );
      }

      await _box!.put(expense.id, expense);
      _logger.i('Expense added with ID: ${expense.id}');

      final currentExpenses = state.valueOrNull?.expenses ?? [];
      final updatedExpenses = [...currentExpenses, expense];

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(
              expenses: updatedExpenses,
              lastUpdated: DateTime.now(),
            ) ??
            ExpenseState(
              expenses: updatedExpenses,
              lastUpdated: DateTime.now(),
            ),
      );

      return expense;
    } on DatabaseException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to add expense', error: e, stackTrace: stackTrace);
      throw DatabaseException.writeFailed(
        operation: 'add expense',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ExpenseModel> updateExpense(ExpenseModel expense) async {
    try {
      _logger.i('Updating expense: ${expense.id}');

      if (_box == null) {
        throw DatabaseException.writeFailed(
          operation: 'update expense',
          error: 'Expense box is not initialized',
        );
      }

      if (!_box!.containsKey(expense.id)) {
        throw DatabaseException.readFailed(
          key: expense.id,
          error: 'Expense not found',
        );
      }

      final validationErrors = expense.validate();
      if (validationErrors.isNotEmpty) {
        throw ValidationException(
          'Expense validation failed: ${validationErrors.join(", ")}',
        );
      }

      await _box!.put(expense.id, expense);
      _logger.i('Expense updated: ${expense.id}');

      final currentExpenses = state.valueOrNull?.expenses ?? [];
      final updatedExpenses = currentExpenses.map((e) {
        return e.id == expense.id ? expense : e;
      }).toList();

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(
              expenses: updatedExpenses,
              lastUpdated: DateTime.now(),
            ) ??
            ExpenseState(
              expenses: updatedExpenses,
              lastUpdated: DateTime.now(),
            ),
      );

      return expense;
    } on DatabaseException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to update expense', error: e, stackTrace: stackTrace);
      throw DatabaseException.writeFailed(
        operation: 'update expense',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    try {
      _logger.i('Deleting expense: $expenseId');

      if (_box == null) {
        throw DatabaseException.deleteFailed(
          key: expenseId,
          error: 'Expense box is not initialized',
        );
      }

      if (!_box!.containsKey(expenseId)) {
        _logger.w('Expense not found for deletion: $expenseId');
        return false;
      }

      await _box!.delete(expenseId);
      _logger.i('Expense deleted: $expenseId');

      final currentExpenses = state.valueOrNull?.expenses ?? [];
      final updatedExpenses = currentExpenses
          .where((e) => e.id != expenseId)
          .toList();

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(
              expenses: updatedExpenses,
              lastUpdated: DateTime.now(),
            ) ??
            ExpenseState(
              expenses: updatedExpenses,
              lastUpdated: DateTime.now(),
            ),
      );

      return true;
    } on DatabaseException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to delete expense', error: e, stackTrace: stackTrace);
      throw DatabaseException.deleteFailed(
        key: expenseId,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  ExpenseModel? getExpenseById(String expenseId) {
    try {
      if (_box == null) {
        _logger.w('Expense box is null');
        return null;
      }

      final expense = _box!.get(expenseId);
      _logger.d(
        'Retrieved expense: $expenseId - ${expense != null ? "found" : "not found"}',
      );
      return expense;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get expense by ID',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseException.readFailed(
        key: expenseId,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  List<ExpenseModel> getExpensesByCategory(ExpenseCategory category) {
    final expenses = state.valueOrNull?.expenses ?? [];
    return expenses.byCategory(category);
  }

  List<ExpenseModel> getExpensesByDateRange(DateTime start, DateTime end) {
    final expenses = state.valueOrNull?.expenses ?? [];
    return expenses.byDateRange(start, end);
  }

  Future<void> refresh() async {
    try {
      _logger.i('Refreshing expenses');

      if (_box == null) {
        throw DatabaseException.readFailed(
          key: 'all expenses',
          error: 'Expense box is not initialized',
        );
      }

      final expenses = _loadExpenses();

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(
              expenses: expenses,
              lastUpdated: DateTime.now(),
            ) ??
            ExpenseState(expenses: expenses, lastUpdated: DateTime.now()),
      );

      _logger.i('Expenses refreshed: ${expenses.length} items');
    } catch (e, stackTrace) {
      _logger.e('Failed to refresh expenses', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> clearAllExpenses() async {
    try {
      _logger.w('Clearing all expenses');

      if (_box == null) {
        throw DatabaseException.deleteFailed(
          key: 'all expenses',
          error: 'Expense box is not initialized',
        );
      }

      await _box!.clear();
      _logger.w('All expenses cleared');

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(
              expenses: [],
              lastUpdated: DateTime.now(),
            ) ??
            ExpenseState(expenses: [], lastUpdated: DateTime.now()),
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to clear expenses', error: e, stackTrace: stackTrace);
      throw DatabaseException.deleteFailed(
        key: 'all expenses',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, dynamic> getStatistics() {
    final expenses = state.valueOrNull?.expenses ?? [];

    return {
      'totalExpenses': expenses.length,
      'totalAmount': expenses.totalAmount,
      'averageAmount': expenses.averageAmount,
      'maxAmount': expenses.maxAmount,
      'minAmount': expenses.minAmount,
      'topCategory': expenses.topSpendingCategory?.displayName,
      'todayCount': expenses.today.length,
      'todayAmount': expenses.today.totalAmount,
      'thisWeekCount': expenses.thisWeek.length,
      'thisWeekAmount': expenses.thisWeek.totalAmount,
      'thisMonthCount': expenses.thisMonth.length,
      'thisMonthAmount': expenses.thisMonth.totalAmount,
      'categoryBreakdown': expenses.groupedByCategory().map(
        (category, expenseList) => MapEntry(category.displayName, {
          'count': expenseList.length,
          'amount': expenseList.totalAmount,
        }),
      ),
    };
  }

  List<ExpenseModel> searchExpenses(String query) {
    if (query.isEmpty) {
      return state.valueOrNull?.expenses ?? [];
    }

    final expenses = state.valueOrNull?.expenses ?? [];
    final lowerQuery = query.toLowerCase();

    return expenses.where((expense) {
      return expense.merchantName.toLowerCase().contains(lowerQuery) ||
          (expense.notes?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}

@riverpod
Map<String, dynamic> expenseStatistics(ExpenseStatisticsRef ref) {
  final expenseState = ref.watch(expenseNotifierProvider);

  return expenseState.when(
    data: (state) {
      final expenses = state.expenses;

      return {
        'totalExpenses': expenses.length,
        'totalAmount': expenses.totalAmount,
        'averageAmount': expenses.averageAmount,
        'maxAmount': expenses.maxAmount,
        'minAmount': expenses.minAmount,
        'topCategory': expenses.topSpendingCategory?.displayName,
        'todayCount': expenses.today.length,
        'todayAmount': expenses.today.totalAmount,
        'thisWeekCount': expenses.thisWeek.length,
        'thisWeekAmount': expenses.thisWeek.totalAmount,
        'thisMonthCount': expenses.thisMonth.length,
        'thisMonthAmount': expenses.thisMonth.totalAmount,
        'categoryBreakdown': expenses.groupedByCategory().map(
          (category, expenseList) => MapEntry(category.displayName, {
            'count': expenseList.length,
            'amount': expenseList.totalAmount,
          }),
        ),
      };
    },
    loading: () => {'isLoading': true},
    error: (error, stack) => {'error': error.toString()},
  );
}

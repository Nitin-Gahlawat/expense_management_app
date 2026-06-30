part of 'expense_provider.dart';

String _$expenseStatisticsHash() => r'8e8fd487ee64051430712294d9a50a4fb09ee0c3';

@ProviderFor(expenseStatistics)
final expenseStatisticsProvider =
    AutoDisposeProvider<Map<String, dynamic>>.internal(
      expenseStatistics,
      name: r'expenseStatisticsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$expenseStatisticsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef ExpenseStatisticsRef = AutoDisposeProviderRef<Map<String, dynamic>>;
String _$expenseNotifierHash() => r'905d39ae08c23671168db6931f30d0a36f4b8ea3';

@ProviderFor(ExpenseNotifier)
final expenseNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ExpenseNotifier, ExpenseState>.internal(
      ExpenseNotifier.new,
      name: r'expenseNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$expenseNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExpenseNotifier = AutoDisposeAsyncNotifier<ExpenseState>;

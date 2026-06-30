part of 'form_provider.dart';

String _$expenseFormNotifierHash() =>
    r'61ae3105aca5b96f24336d66a8ec478b256ab1b4';

@ProviderFor(ExpenseFormNotifier)
final expenseFormNotifierProvider =
    AutoDisposeNotifierProvider<ExpenseFormNotifier, ExpenseFormState>.internal(
      ExpenseFormNotifier.new,
      name: r'expenseFormNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$expenseFormNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExpenseFormNotifier = AutoDisposeNotifier<ExpenseFormState>;

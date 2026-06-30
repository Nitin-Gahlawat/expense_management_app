
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:logger/logger.dart';
import '../models/expense_category.dart';

part 'form_provider.g.dart';

class FieldState {
  final String value;
  final String? error;
  final bool isTouched;
  final bool isValid;

  const FieldState({
    this.value = '',
    this.error,
    this.isTouched = false,
    this.isValid = true,
  });

  FieldState copyWith({
    String? value,
    String? error,
    bool? isTouched,
    bool? isValid,
    bool clearError = false,
  }) {
    return FieldState(
      value: value ?? this.value,
      error: clearError ? null : (error ?? this.error),
      isTouched: isTouched ?? this.isTouched,
      isValid: isValid ?? this.isValid,
    );
  }

  bool get hasError => error != null && error!.isNotEmpty;

  bool get isEmpty => value.isEmpty;

  bool get isNotEmpty => value.isNotEmpty;
}

class ExpenseFormState {
  final FieldState merchantName;
  final FieldState amount;
  final FieldState date;
  final ExpenseCategory? category;
  final FieldState notes;
  final bool isSubmitting;
  final String? submissionError;
  final bool isValid;

  const ExpenseFormState({
    this.merchantName = const FieldState(),
    this.amount = const FieldState(),
    this.date = const FieldState(),
    this.category,
    this.notes = const FieldState(),
    this.isSubmitting = false,
    this.submissionError,
    this.isValid = false,
  });

  ExpenseFormState copyWith({
    FieldState? merchantName,
    FieldState? amount,
    FieldState? date,
    ExpenseCategory? category,
    FieldState? notes,
    bool? isSubmitting,
    String? submissionError,
    bool? isValid,
    bool clearSubmissionError = false,
    bool clearCategory = false,
  }) {
    return ExpenseFormState(
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: clearCategory ? null : (category ?? this.category),
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: clearSubmissionError
          ? null
          : (submissionError ?? this.submissionError),
      isValid: isValid ?? this.isValid,
    );
  }

  bool get hasErrors =>
      merchantName.hasError ||
      amount.hasError ||
      date.hasError ||
      notes.hasError;

  bool get isComplete =>
      merchantName.isNotEmpty &&
      amount.isNotEmpty &&
      date.isNotEmpty &&
      category != null;

  bool get canSubmit => isComplete && !hasErrors && !isSubmitting && isValid;
}

@riverpod
class ExpenseFormNotifier extends _$ExpenseFormNotifier {
  late final Logger _logger;

  @override
  ExpenseFormState build() {
    _logger = Logger();
    _logger.i('Building ExpenseFormNotifier');

    return const ExpenseFormState(
      date: FieldState(value: ''), // Will be initialized with today's date
    );
  }

  void updateMerchantName(String value) {
    _logger.d('Updating merchant name: $value');

    final fieldState = _validateMerchantName(value);

    state = state.copyWith(
      merchantName: fieldState.copyWith(
        value: value,
        isTouched: true,
        error: fieldState.error,
        isValid: fieldState.isValid,
      ),
    );

    _updateFormValidity();
  }

  void updateAmount(String value) {
    _logger.d('Updating amount: $value');

    final fieldState = _validateAmount(value);

    state = state.copyWith(
      amount: fieldState.copyWith(
        value: value,
        isTouched: true,
        error: fieldState.error,
        isValid: fieldState.isValid,
      ),
    );

    _updateFormValidity();
  }

  void updateDate(String value) {
    _logger.d('Updating date: $value');

    final fieldState = _validateDate(value);

    state = state.copyWith(
      date: fieldState.copyWith(
        value: value,
        isTouched: true,
        error: fieldState.error,
        isValid: fieldState.isValid,
      ),
    );

    _updateFormValidity();
  }

  void updateCategory(ExpenseCategory? category) {
    _logger.d('Updating category: ${category?.displayName}');

    state = state.copyWith(category: category);
    _updateFormValidity();
  }

  void updateNotes(String value) {
    _logger.d('Updating notes: ${value.length} characters');

    final fieldState = _validateNotes(value);

    state = state.copyWith(
      notes: fieldState.copyWith(
        value: value,
        isTouched: true,
        error: fieldState.error,
        isValid: fieldState.isValid,
      ),
    );

    _updateFormValidity();
  }

  FieldState _validateMerchantName(String value) {
    if (value.trim().isEmpty) {
      return const FieldState(
        value: '',
        error: 'Merchant name is required',
        isValid: false,
      );
    }

    if (value.length > 100) {
      return FieldState(
        value: value,
        error: 'Merchant name cannot exceed 100 characters',
        isValid: false,
      );
    }

    return FieldState(value: value, isValid: true);
  }

  FieldState _validateAmount(String value) {
    if (value.trim().isEmpty) {
      return const FieldState(
        value: '',
        error: 'Amount is required',
        isValid: false,
      );
    }

    final amount = double.tryParse(value);
    if (amount == null) {
      return FieldState(
        value: value,
        error: 'Please enter a valid number',
        isValid: false,
      );
    }

    if (amount <= 0) {
      return FieldState(
        value: value,
        error: 'Amount must be greater than 0',
        isValid: false,
      );
    }

    if (amount > 1000000) {
      return FieldState(
        value: value,
        error: 'Amount cannot exceed 1,000,000',
        isValid: false,
      );
    }

    return FieldState(value: value, isValid: true);
  }

  FieldState _validateDate(String value) {
    if (value.trim().isEmpty) {
      return const FieldState(
        value: '',
        error: 'Date is required',
        isValid: false,
      );
    }

    try {
      final date = DateTime.parse(value);
      final now = DateTime.now();

      if (date.isAfter(now.add(const Duration(days: 30)))) {
        return FieldState(
          value: value,
          error: 'Date cannot be more than 30 days in the future',
          isValid: false,
        );
      }

      if (date.isBefore(now.subtract(const Duration(days: 365 * 10)))) {
        return FieldState(
          value: value,
          error: 'Date cannot be more than 10 years in the past',
          isValid: false,
        );
      }

      return FieldState(value: value, isValid: true);
    } catch (e) {
      return FieldState(
        value: value,
        error: 'Please enter a valid date (YYYY-MM-DD)',
        isValid: false,
      );
    }
  }

  FieldState _validateNotes(String value) {
    if (value.length > 500) {
      return FieldState(
        value: value,
        error: 'Notes cannot exceed 500 characters',
        isValid: false,
      );
    }

    return FieldState(value: value, isValid: true);
  }

  void _updateFormValidity() {
    final isValid =
        state.merchantName.isValid &&
        state.amount.isValid &&
        state.date.isValid &&
        state.notes.isValid &&
        state.category != null;

    state = state.copyWith(isValid: isValid);
  }

  bool validateForm() {
    _logger.i('Validating form');

    // Touch all fields to show errors
    updateMerchantName(state.merchantName.value);
    updateAmount(state.amount.value);
    updateDate(state.date.value);
    updateNotes(state.notes.value);

    // Check if category is selected
    if (state.category == null) {
      _logger.w('Category not selected');
    }

    final isValid = state.canSubmit;
    _logger.i('Form validation result: $isValid');

    return isValid;
  }

  void resetForm() {
    _logger.i('Resetting form');

    state = const ExpenseFormState(date: FieldState(value: ''));
  }

  void fillFromScan({
    required String merchantName,
    required double amount,
    required DateTime date,
    required ExpenseCategory category,
    String? notes,
  }) {
    _logger.i('Filling form from scan: $merchantName, \$$amount');

    // Format date as ISO string
    final dateString = date.toIso8601String().split('T')[0];

    // Update all fields
    updateMerchantName(merchantName);
    updateAmount(amount.toStringAsFixed(2));
    updateDate(dateString);
    updateCategory(category);

    if (notes != null && notes.isNotEmpty) {
      updateNotes(notes);
    }

    _logger.i('Form filled from scan successfully');
  }

  void fillFromExpense({
    required String merchantName,
    required double amount,
    required DateTime date,
    required ExpenseCategory category,
    String? notes,
  }) {
    _logger.i('Filling form from expense: $merchantName, \$$amount');

    // Format date as ISO string
    final dateString = date.toIso8601String().split('T')[0];

    // Update all fields
    updateMerchantName(merchantName);
    updateAmount(amount.toStringAsFixed(2));
    updateDate(dateString);
    updateCategory(category);

    if (notes != null && notes.isNotEmpty) {
      updateNotes(notes);
    }

    _logger.i('Form filled from expense successfully');
  }

  void setSubmitting(bool isSubmitting) {
    _logger.d('Setting submitting state: $isSubmitting');
    state = state.copyWith(isSubmitting: isSubmitting);
  }

  void setSubmissionError(String error) {
    _logger.e('Setting submission error: $error');
    state = state.copyWith(submissionError: error, isSubmitting: false);
  }

  void clearSubmissionError() {
    _logger.d('Clearing submission error');
    state = state.copyWith(clearSubmissionError: true);
  }

  void initializeWithTodayDate() {
    final today = DateTime.now();
    final dateString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    _logger.d('Initializing with today\'s date: $dateString');
    updateDate(dateString);
  }

  Map<String, dynamic> getFormData() {
    return {
      'merchantName': state.merchantName.value.trim(),
      'amount': double.parse(state.amount.value),
      'date': DateTime.parse(state.date.value),
      'category': state.category,
      'notes': state.notes.value.trim().isEmpty
          ? null
          : state.notes.value.trim(),
    };
  }

  bool get isModified =>
      state.merchantName.isNotEmpty ||
      state.amount.isNotEmpty ||
      state.date.isNotEmpty ||
      state.category != null ||
      state.notes.isNotEmpty;
}

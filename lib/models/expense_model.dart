import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'expense_category.dart';
import '../core/errors.dart';

part 'expense_model.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 0)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String merchantName;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final ExpenseCategory category;

  @HiveField(5)
  final Map<String, dynamic>? rawAiResponse;

  @HiveField(6)
  final String? notes;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final bool isAiGenerated;

  @HiveField(10)
  final String? receiptImagePath;

  ExpenseModel({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.category,
    this.rawAiResponse,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isAiGenerated = false,
    this.receiptImagePath,
  });

  factory ExpenseModel.create({
    required String merchantName,
    required double amount,
    required DateTime date,
    required ExpenseCategory category,
    Map<String, dynamic>? rawAiResponse,
    String? notes,
    bool isAiGenerated = false,
    String? receiptImagePath,
  }) {
    final now = DateTime.now();
    return ExpenseModel(
      id: _uuid.v4(),
      merchantName: merchantName,
      amount: amount,
      date: date,
      category: category,
      rawAiResponse: rawAiResponse,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      isAiGenerated: isAiGenerated,
      receiptImagePath: receiptImagePath,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? merchantName,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
    Map<String, dynamic>? rawAiResponse,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAiGenerated,
    String? receiptImagePath,
    bool clearRawAiResponse = false,
    bool clearNotes = false,
    bool clearReceiptImagePath = false,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      rawAiResponse: clearRawAiResponse
          ? null
          : (rawAiResponse ?? this.rawAiResponse),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      receiptImagePath: clearReceiptImagePath
          ? null
          : (receiptImagePath ?? this.receiptImagePath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantName': merchantName,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.serializeValue,
      'rawAiResponse': rawAiResponse,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isAiGenerated': isAiGenerated,
      'receiptImagePath': receiptImagePath,
    };
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String?;
      if (id == null || id.isEmpty) {
        throw ValidationException.requiredField(fieldName: 'id');
      }

      final merchantName = json['merchantName'] as String?;
      if (merchantName == null || merchantName.isEmpty) {
        throw ValidationException.requiredField(fieldName: 'merchantName');
      }

      final amount = json['amount'] as num?;
      if (amount == null) {
        throw ValidationException.requiredField(fieldName: 'amount');
      }

      final dateString = json['date'] as String?;
      if (dateString == null || dateString.isEmpty) {
        throw ValidationException.requiredField(fieldName: 'date');
      }

      final categoryString = json['category'] as String?;
      if (categoryString == null || categoryString.isEmpty) {
        throw ValidationException.requiredField(fieldName: 'category');
      }

      final createdAtString = json['createdAt'] as String?;
      if (createdAtString == null || createdAtString.isEmpty) {
        throw ValidationException.requiredField(fieldName: 'createdAt');
      }

      final updatedAtString = json['updatedAt'] as String?;
      if (updatedAtString == null || updatedAtString.isEmpty) {
        throw ValidationException.requiredField(fieldName: 'updatedAt');
      }

      final date = DateTime.parse(dateString);
      final createdAt = DateTime.parse(createdAtString);
      final updatedAt = DateTime.parse(updatedAtString);

      final category = ExpenseCategoryExtension.fromString(categoryString);

      return ExpenseModel(
        id: id,
        merchantName: merchantName,
        amount: amount.toDouble(),
        date: date,
        category: category,
        rawAiResponse: json['rawAiResponse'] as Map<String, dynamic>?,
        notes: json['notes'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isAiGenerated: json['isAiGenerated'] as bool? ?? false,
        receiptImagePath: json['receiptImagePath'] as String?,
      );
    } catch (e) {
      if (e is ValidationException) {
        rethrow;
      }
      throw ValidationException(
        'Failed to parse ExpenseModel from JSON',
        innerException: e,
      );
    }
  }

  List<String> validate() {
    final errors = <String>[];

    if (id.isEmpty) {
      errors.add('ID cannot be empty');
    }

    if (merchantName.trim().isEmpty) {
      errors.add('Merchant name cannot be empty');
    } else if (merchantName.length > 100) {
      errors.add('Merchant name cannot exceed 100 characters');
    }

    if (amount <= 0) {
      errors.add('Amount must be greater than 0');
    } else if (amount > 1000000) {
      errors.add('Amount cannot exceed 1,000,000');
    }

    if (date.isAfter(DateTime.now().add(const Duration(days: 30)))) {
      errors.add('Date cannot be more than 30 days in the future');
    }
    if (date.isBefore(
      DateTime.now().subtract(const Duration(days: 365 * 10)),
    )) {
      errors.add('Date cannot be more than 10 years in the past');
    }

    if (notes != null && notes!.length > 500) {
      errors.add('Notes cannot exceed 500 characters');
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  String get formattedAmount {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedDateTime {
    return '${formattedDate} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool get hasReceiptImage =>
      receiptImagePath != null && receiptImagePath!.isNotEmpty;

  String get summary {
    return '$merchantName - $formattedAmount (${category.displayName})';
  }

  @override
  String toString() {
    return 'ExpenseModel(id: $id, merchantName: $merchantName, amount: $amount, '
        'date: $formattedDate, category: ${category.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

extension ExpenseListExtension on List<ExpenseModel> {
  List<ExpenseModel> byCategory(ExpenseCategory category) {
    return where((expense) => expense.category == category).toList();
  }

  List<ExpenseModel> byDateRange(DateTime start, DateTime end) {
    return where(
      (expense) =>
          expense.date.isAfter(start.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(end.add(const Duration(days: 1))),
    ).toList();
  }

  List<ExpenseModel> get today => where((expense) => expense.isToday).toList();

  List<ExpenseModel> get thisWeek =>
      where((expense) => expense.isThisWeek).toList();

  List<ExpenseModel> get thisMonth =>
      where((expense) => expense.isThisMonth).toList();

  double get totalAmount => fold(0.0, (sum, expense) => sum + expense.amount);

  double totalByCategory(ExpenseCategory category) {
    return where(
      (expense) => expense.category == category,
    ).fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<ExpenseCategory, List<ExpenseModel>> groupedByCategory() {
    final map = <ExpenseCategory, List<ExpenseModel>>{};
    for (final category in ExpenseCategory.values) {
      map[category] = byCategory(category);
    }
    return map;
  }

  List<ExpenseModel> sortedByDateDesc() {
    return [...this]..sort((a, b) => b.date.compareTo(a.date));
  }

  List<ExpenseModel> sortedByDateAsc() {
    return [...this]..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ExpenseModel> sortedByAmountDesc() {
    return [...this]..sort((a, b) => b.amount.compareTo(a.amount));
  }

  List<ExpenseModel> sortedByAmountAsc() {
    return [...this]..sort((a, b) => a.amount.compareTo(b.amount));
  }

  ExpenseCategory? get topSpendingCategory {
    if (isEmpty) return null;

    final totals = <ExpenseCategory, double>{};
    for (final expense in this) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }

    return totals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get averageAmount => isEmpty ? 0.0 : totalAmount / length;

  double get maxAmount =>
      isEmpty ? 0.0 : map((e) => e.amount).reduce((a, b) => a > b ? a : b);

  double get minAmount =>
      isEmpty ? 0.0 : map((e) => e.amount).reduce((a, b) => a < b ? a : b);
}

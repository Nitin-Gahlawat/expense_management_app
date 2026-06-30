import 'expense_category.dart';

class ReceiptScanResponse {
  final String merchantName;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? notes;
  final String? confidence;
  final Map<String, dynamic>? rawResponse;

  const ReceiptScanResponse({
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
    this.confidence,
    this.rawResponse,
  });

  factory ReceiptScanResponse.fromJson(Map<String, dynamic> json) {
    return ReceiptScanResponse(
      merchantName: json['merchantName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      category: ExpenseCategoryExtension.fromString(
        json['category'] as String? ?? 'others',
      ),
      notes: json['notes'] as String?,
      confidence: json['confidence'] as String?,
      rawResponse: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantName': merchantName,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.serializeValue,
      if (notes != null) 'notes': notes,
      if (confidence != null) 'confidence': confidence,
    };
  }

  @override
  String toString() {
    return 'ReceiptScanResponse(merchant: $merchantName, amount: \$${amount.toStringAsFixed(2)}, '
        'date: ${date.toIso8601String()}, category: ${category.displayName}, notes: $notes)';
  }
}

class SpendingInsightsResponse {
  final String summary;
  final double totalSpending;
  final List<CategorySpending> topCategories;
  final String recommendation;
  final Map<String, dynamic>? rawResponse;

  const SpendingInsightsResponse({
    required this.summary,
    required this.totalSpending,
    required this.topCategories,
    required this.recommendation,
    this.rawResponse,
  });

  factory SpendingInsightsResponse.fromJson(Map<String, dynamic> json) {
    final topCategoriesList =
        (json['topCategories'] as List?)
            ?.map((e) => CategorySpending.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <CategorySpending>[];

    return SpendingInsightsResponse(
      summary: json['summary'] as String? ?? '',
      totalSpending: (json['totalSpending'] as num?)?.toDouble() ?? 0.0,
      topCategories: topCategoriesList,
      recommendation: json['recommendation'] as String? ?? '',
      rawResponse: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'totalSpending': totalSpending,
      'topCategories': topCategories.map((e) => e.toJson()).toList(),
      'recommendation': recommendation,
    };
  }

  @override
  String toString() {
    return 'SpendingInsightsResponse(total: \$${totalSpending.toStringAsFixed(2)}, '
        'categories: ${topCategories.length})';
  }
}

class CategorySpending {
  final String category;
  final double amount;
  final double percentage;

  const CategorySpending({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  factory CategorySpending.fromJson(Map<String, dynamic> json) {
    return CategorySpending(
      category: json['category'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'category': category, 'amount': amount, 'percentage': percentage};
  }
}

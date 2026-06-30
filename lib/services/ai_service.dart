
import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';
import '../models/expense_model.dart';
import '../models/expense_category.dart';
import '../models/receipt_scan_response.dart';
import '../models/spending_insights_response.dart';
import '../core/errors.dart';

class AIService {
  final String apiKey;
  final GenerativeModel model;
  final Logger logger;

  static const int maxImageSizeBytes = 4 * 1024 * 1024;


  AIService({required this.apiKey, Logger? logger})
    : model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey),
      logger = logger ?? Logger();


  Future<ReceiptScanResponse> scanReceipt(File imageFile) async {
    try {
      logger.i('Starting receipt scan for: ${imageFile.path}');

      // Validate image file exists
      if (!await imageFile.exists()) {
        throw ImageException.fileAccessFailed(
          path: imageFile.path,
          error: 'File does not exist',
        );
      }

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();

      // Validate image size
      if (imageBytes.isEmpty) {
        throw ImageException.invalidFormat(
          format: 'Empty file',
          error: 'Image file is empty',
        );
      }

      if (imageBytes.length > maxImageSizeBytes) {
        throw ImageException.sizeLimitExceeded(
          maxSizeBytes: maxImageSizeBytes,
          actualSizeBytes: imageBytes.length,
        );
      }

      logger.d('Image size: ${imageBytes.length} bytes');

      // Prepare the image part
      final imagePart = DataPart('image/jpeg', imageBytes);

      // Define the structured schema for receipt scanning
      final schema = Schema.object(
        properties: {
          'merchantName': Schema.string(
            description: 'The name of the merchant or business on the receipt',
          ),
          'amount': Schema.number(
            description: 'The total amount spent as a number (not a string)',
          ),
          'date': Schema.string(
            description:
                'The date of the transaction in ISO 8601 format (YYYY-MM-DD)',
          ),
          'category': Schema.string(
            description:
                'The expense category. Must be one of: food, shopping, travel, utilities, entertainment, others',
          ),
          'notes': Schema.string(
            description:
                'Additional notes from the receipt such as items purchased, payment method, or other relevant details',
          ),
          'confidence': Schema.string(
            description:
                'Confidence level of the extraction (high, medium, low)',
          ),
        },
        requiredProperties: const [
          'merchantName',
          'amount',
          'date',
          'category',
        ],
      );

      // Create the generation config with schema
      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.1, // Low temperature for more deterministic outputs
      );

      // Prepare the prompt
      final prompt = TextPart(
        '''Analyze this receipt image and extract the following information:
1. Merchant name - the business or vendor name
2. Amount - the total amount spent (as a number)
3. Date - the transaction date in YYYY-MM-DD format
4. Category - categorize this expense as one of: food, shopping, travel, utilities, entertainment, or others
5. Notes - any additional details from the receipt such as items purchased, payment method, or other relevant information
6. Confidence - how confident are you in this extraction (high, medium, low)

Return the data in the specified JSON format. Be precise and accurate with the amounts and dates.''',
      );

      logger.d('Sending request to Gemini AI');

      // Generate content
      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ], generationConfig: config);

      logger.d('Received response from Gemini AI');

      // Validate response
      if (response.text == null || response.text!.isEmpty) {
        throw AIException.responseParsingFailed(
          expectedFormat: 'JSON with merchantName, amount, date, category',
          error: 'Empty response from AI',
        );
      }

      // Parse the JSON response
      final jsonResponse = jsonDecode(response.text!) as Map<String, dynamic>;
      logger.d('Parsed JSON response: $jsonResponse');

      // Validate required fields
      final merchantName = jsonResponse['merchantName'] as String?;
      if (merchantName == null || merchantName.trim().isEmpty) {
        throw AIException.invalidResponseStructure(
          missingField: 'merchantName',
        );
      }

      final amount = jsonResponse['amount'] as num?;
      if (amount == null) {
        throw AIException.invalidResponseStructure(missingField: 'amount');
      }

      final dateString = jsonResponse['date'] as String?;
      if (dateString == null || dateString.isEmpty) {
        throw AIException.invalidResponseStructure(missingField: 'date');
      }

      final categoryString = jsonResponse['category'] as String?;
      if (categoryString == null || categoryString.isEmpty) {
        throw AIException.invalidResponseStructure(missingField: 'category');
      }

      // Parse and validate date
      DateTime date;
      try {
        date = DateTime.parse(dateString);
      } catch (e) {
        throw AIException.invalidResponseStructure(
          missingField: 'date (invalid format)',
        );
      }

      // Parse category
      final category = ExpenseCategoryExtension.fromString(categoryString);

      // Create response object
      final scanResponse = ReceiptScanResponse(
        merchantName: merchantName.trim(),
        amount: amount.toDouble(),
        date: date,
        category: category,
        notes: jsonResponse['notes'] as String?,
        confidence: jsonResponse['confidence'] as String?,
        rawResponse: jsonResponse,
      );

      logger.i('Receipt scan successful: $scanResponse');

      return scanResponse;
    } on AIException {
      rethrow;
    } on ImageException {
      rethrow;
    } on FormatException catch (e, stackTrace) {
      logger.e('JSON parsing error', error: e, stackTrace: stackTrace);
      throw AIException.responseParsingFailed(
        expectedFormat: 'Valid JSON',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      logger.e(
        'Unexpected error during receipt scan',
        error: e,
        stackTrace: stackTrace,
      );
      throw AIException.inferenceFailed(
        reason: e.toString(),
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<SpendingInsightsResponse> generateInsights(
    List<ExpenseModel> expenses,
  ) async {
    try {
      logger.i('Generating insights for ${expenses.length} expenses');

      if (expenses.isEmpty) {
        throw AIException.invalidInput(
          reason: 'Cannot generate insights for empty expense list',
        );
      }

      // Calculate total spending
      final totalSpending = expenses.totalAmount;

      // Group by category
      final categoryTotals = <String, double>{};
      for (final expense in expenses) {
        categoryTotals[expense.category.displayName] =
            (categoryTotals[expense.category.displayName] ?? 0) +
            expense.amount;
      }

      // Sort categories by spending
      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Format expense data for the prompt
      final expenseData = expenses
          .map(
            (e) =>
                '${e.date.toIso8601String()},${e.merchantName},${e.amount.toStringAsFixed(2)},${e.category.displayName}',
          )
          .join('\n');

      // Define the structured schema for insights
      final schema = Schema.object(
        properties: {
          'summary': Schema.string(
            description:
                'A brief 2-3 sentence summary of the spending patterns',
          ),
          'totalSpending': Schema.number(
            description: 'The total amount spent across all expenses',
          ),
          'topCategories': Schema.array(
            description:
                'List of top spending categories with amounts and percentages',
            items: Schema.object(
              properties: {
                'category': Schema.string(description: 'Category name'),
                'amount': Schema.number(
                  description: 'Amount spent in this category',
                ),
                'percentage': Schema.number(
                  description: 'Percentage of total spending (0-100)',
                ),
              },
              requiredProperties: const ['category', 'amount', 'percentage'],
            ),
          ),
          'recommendation': Schema.string(
            description:
                'A specific, actionable financial recommendation based on the spending data',
          ),
        },
        requiredProperties: const [
          'summary',
          'totalSpending',
          'topCategories',
          'recommendation',
        ],
      );

      // Create the generation config with schema
      final config = GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature:
            0.3, // Slightly higher temperature for more creative insights
      );

      // Prepare the prompt
      final prompt = TextPart(
        '''Analyze the following expense data and provide spending insights:

Total Expenses: ${expenses.length}
Total Spending: \$${totalSpending.toStringAsFixed(2)}
Date Range: ${expenses.sortedByDateAsc().first.formattedDate} to ${expenses.sortedByDateDesc().first.formattedDate}

Expense Data (Date, Merchant, Amount, Category):
$expenseData

Category Breakdown:
${sortedCategories.map((e) => '${e.key}: \$${e.value.toStringAsFixed(2)}').join('\n')}

Provide:
1. A brief summary of spending patterns
2. The total spending amount
3. Top 3-5 spending categories with amounts and percentages
4. One specific, actionable financial recommendation

Be helpful, specific, and practical in your recommendation.''',
      );

      logger.d('Sending insights request to Gemini AI');

      // Generate content
      final response = await model.generateContent([
        Content.multi([prompt]),
      ], generationConfig: config);

      logger.d('Received insights response from Gemini AI');

      // Validate response
      if (response.text == null || response.text!.isEmpty) {
        throw AIException.responseParsingFailed(
          expectedFormat:
              'JSON with summary, totalSpending, topCategories, recommendation',
          error: 'Empty response from AI',
        );
      }

      // Parse the JSON response
      final jsonResponse = jsonDecode(response.text!) as Map<String, dynamic>;
      logger.d('Parsed insights JSON: $jsonResponse');

      // Validate required fields
      final summary = jsonResponse['summary'] as String?;
      if (summary == null || summary.isEmpty) {
        throw AIException.invalidResponseStructure(missingField: 'summary');
      }

      final total = jsonResponse['totalSpending'] as num?;
      if (total == null) {
        throw AIException.invalidResponseStructure(
          missingField: 'totalSpending',
        );
      }

      final topCategoriesList = jsonResponse['topCategories'] as List?;
      if (topCategoriesList == null || topCategoriesList.isEmpty) {
        throw AIException.invalidResponseStructure(
          missingField: 'topCategories',
        );
      }

      final recommendation = jsonResponse['recommendation'] as String?;
      if (recommendation == null || recommendation.isEmpty) {
        throw AIException.invalidResponseStructure(
          missingField: 'recommendation',
        );
      }

      // Create response object
      final insightsResponse = SpendingInsightsResponse(
        summary: summary,
        totalSpending: total.toDouble(),
        topCategories: topCategoriesList
            .map((e) => CategorySpending.fromJson(e as Map<String, dynamic>))
            .toList(),
        recommendation: recommendation,
        rawResponse: jsonResponse,
      );

      logger.i('Insights generation successful: $insightsResponse');

      return insightsResponse;
    } on AIException {
      rethrow;
    } on FormatException catch (e, stackTrace) {
      logger.e('JSON parsing error', error: e, stackTrace: stackTrace);
      throw AIException.responseParsingFailed(
        expectedFormat: 'Valid JSON',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      logger.e(
        'Unexpected error during insights generation',
        error: e,
        stackTrace: stackTrace,
      );
      throw AIException.inferenceFailed(
        reason: e.toString(),
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> validateApiKey() async {
    try {
      logger.i('Validating API key');

      final testPrompt = TextPart(
        'Respond with "OK" if you receive this message.',
      );
      final response = await model.generateContent([
        Content.multi([testPrompt]),
      ]);

      final isValid =
          response.text != null && response.text!.toLowerCase().contains('ok');

      logger.i('API key validation result: $isValid');
      return isValid;
    } on GenerativeAIException catch (e, stackTrace) {
      logger.e('API key validation failed', error: e, stackTrace: stackTrace);

      if (e.message?.contains('API key') == true ||
          e.message?.contains('authentication') == true) {
        throw NetworkException.invalidApiKey(error: e, stackTrace: stackTrace);
      }

      throw NetworkException.connectionFailed(error: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      logger.e(
        'Unexpected error during API key validation',
        error: e,
        stackTrace: stackTrace,
      );
      throw NetworkException.connectionFailed(error: e, stackTrace: stackTrace);
    }
  }
}

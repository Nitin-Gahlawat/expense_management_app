
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:logger/logger.dart';
import '../services/ai_service.dart';
import '../models/expense_model.dart';
import '../models/spending_insights_response.dart';
import '../core/errors.dart';

part 'insights_provider.g.dart';


class InsightsState {
  final SpendingInsightsResponse? insights;
  final bool isLoading;
  final String? error;
  final DateTime? lastGenerated;
  final DateTime? cacheExpiry;

  const InsightsState({
    this.insights,
    this.isLoading = false,
    this.error,
    this.lastGenerated,
    this.cacheExpiry,
  });

  InsightsState copyWith({
    SpendingInsightsResponse? insights,
    bool? isLoading,
    String? error,
    DateTime? lastGenerated,
    DateTime? cacheExpiry,
    bool clearError = false,
  }) {
    return InsightsState(
      insights: insights ?? this.insights,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastGenerated: lastGenerated ?? this.lastGenerated,
      cacheExpiry: cacheExpiry ?? this.cacheExpiry,
    );
  }

  bool get hasInsights => insights != null;

  bool get isCacheExpired {
    if (cacheExpiry == null) return true;
    return DateTime.now().isAfter(cacheExpiry!);
  }

  bool get shouldRefresh => !hasInsights || isCacheExpired;
}

@riverpod
class InsightsNotifier extends _$InsightsNotifier {
  late final Logger _logger;
  AIService? _aiService;

  static const int _cacheDurationHours = 1;

  @override
  Future<InsightsState> build() async {
    _logger = Logger();
    _logger.i('Building InsightsNotifier');

    try {
      _aiService = null;

      _logger.i('InsightsNotifier built successfully');

      return const InsightsState();
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to build InsightsNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void initializeAI(String apiKey) {
    _logger.i('Initializing AI service');

    if (apiKey.trim().isEmpty) {
      throw ValidationException.requiredField(fieldName: 'API key');
    }

    _aiService = AIService(apiKey: apiKey, logger: _logger);
    _logger.i('AI service initialized');
  }

  
  Future<SpendingInsightsResponse> generateInsights(
    List<ExpenseModel> expenses, {
    bool forceRefresh = false,
  }) async {
    try {
      _logger.i('Generating insights for ${expenses.length} expenses');

      if (_aiService == null) {
        throw AIException.modelInitializationFailed(
          modelName: 'gemini-2.5-flash',
          error: 'AI service not initialized. Call initializeAI first.',
        );
      }

      if (!forceRefresh && state.valueOrNull?.hasInsights == true) {
        final currentState = state.valueOrNull!;
        if (!currentState.isCacheExpired) {
          _logger.i('Returning cached insights');
          return currentState.insights!;
        }
      }

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(isLoading: true, clearError: true) ??
            const InsightsState(isLoading: true),
      );

      if (expenses.isEmpty) {
        throw AIException.invalidInput(
          reason: 'Cannot generate insights for empty expense list',
        );
      }

      final insights = await _aiService!.generateInsights(expenses);

      _logger.i('Insights generated successfully');

      final cacheExpiry = DateTime.now().add(
        Duration(hours: _cacheDurationHours),
      );


      state = AsyncValue.data(
        InsightsState(
          insights: insights,
          isLoading: false,
          lastGenerated: DateTime.now(),
          cacheExpiry: cacheExpiry,
        ),
      );

      return insights;
    } on AIException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to generate insights',
        error: e,
        stackTrace: stackTrace,
      );

      state = AsyncValue.data(
        state.valueOrNull?.copyWith(isLoading: false, error: e.toString()) ??
            InsightsState(isLoading: false, error: e.toString()),
      );

      throw AIException.inferenceFailed(
        reason: e.toString(),
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<SpendingInsightsResponse> refreshInsights(
    List<ExpenseModel> expenses,
  ) async {
    _logger.i('Refreshing insights');
    return generateInsights(expenses, forceRefresh: true);
  }


  void clearCache() {
    _logger.i('Clearing insights cache');

    state = AsyncValue.data(
      state.valueOrNull?.copyWith(
            insights: null,
            lastGenerated: null,
            cacheExpiry: null,
            clearError: true,
          ) ??
          const InsightsState(),
    );
  }

  Future<bool> validateApiKey() async {
    try {
      _logger.i('Validating API key');

      if (_aiService == null) {
        throw ValidationException.requiredField(fieldName: 'AI service');
      }

      final isValid = await _aiService!.validateApiKey();
      _logger.i('API key validation result: $isValid');

      return isValid;
    } on ValidationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Failed to validate API key', error: e, stackTrace: stackTrace);
      throw NetworkException.connectionFailed(error: e, stackTrace: stackTrace);
    }
  }


  SpendingInsightsResponse? getCurrentInsights() {
    final currentState = state.valueOrNull;

    if (currentState == null || !currentState.hasInsights) {
      return null;
    }

    if (currentState.isCacheExpired) {
      _logger.d('Cached insights have expired');
      return null;
    }

    _logger.d('Returning current insights from cache');
    return currentState.insights;
  }

  bool get isGenerating {
    return state.valueOrNull?.isLoading ?? false;
  }

  DateTime? getLastGeneratedTime() {
    return state.valueOrNull?.lastGenerated;
  }


  DateTime? getCacheExpiryTime() {
    return state.valueOrNull?.cacheExpiry;
  }

  String? getError() {
    return state.valueOrNull?.error;
  }

  void clearError() {
    _logger.d('Clearing error state');

    state = AsyncValue.data(
      state.valueOrNull?.copyWith(clearError: true) ?? const InsightsState(),
    );
  }

  void dispose() {
    _logger.i('Disposing InsightsNotifier');
    _aiService = null;
  }
}

@riverpod
String insightsMarkdown(InsightsMarkdownRef ref) {
  final insightsState = ref.watch(insightsNotifierProvider);

  return insightsState.when(
    data: (state) {
      if (state.insights == null) {
        return 'No insights available. Generate insights to see your spending analysis.';
      }

      final insights = state.insights!;
      final buffer = StringBuffer();

      buffer.writeln('# Spending Insights\n');
      buffer.writeln('## Summary\n');
      buffer.writeln(insights.summary);
      buffer.writeln('\n');

      buffer.writeln('## Total Spending\n');
      buffer.writeln('**\$${insights.totalSpending.toStringAsFixed(2)}**');
      buffer.writeln('\n');


      buffer.writeln('## Top Spending Categories\n');
      for (final category in insights.topCategories) {
        buffer.writeln(
          '- **${category.category}**: \$${category.amount.toStringAsFixed(2)} '
          '(${category.percentage.toStringAsFixed(1)}%)',
        );
      }
      buffer.writeln('\n');

      buffer.writeln('## Recommendation\n');
      buffer.writeln(insights.recommendation);
      buffer.writeln('\n');


      if (state.lastGenerated != null) {
        buffer.writeln('---\n');
        buffer.writeln('*Last updated: ${state.lastGenerated}*');
      }

      return buffer.toString();
    },
    loading: () => 'Loading insights...',
    error: (error, stack) => 'Error loading insights: $error',
  );
}

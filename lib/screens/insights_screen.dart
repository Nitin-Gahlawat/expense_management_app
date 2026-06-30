
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import '../providers/insights_provider.dart';
import '../services/storage_service.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    // Load insights when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInsights();
    });
  }

  Future<void> _loadInsights() async {
    final expenseState = ref.read(expenseNotifierProvider);
    final expenses = expenseState.valueOrNull?.expenses ?? [];

    if (expenses.isEmpty) {
      return;
    }

    // Initialize AI service with API key from Hive storage
    final apiKey = StorageService.getGeminiApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      ref.read(insightsNotifierProvider.notifier).initializeAI(apiKey);
      await ref.read(insightsNotifierProvider.notifier).generateInsights(expenses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insightsState = ref.watch(insightsNotifierProvider);
    final expenseState = ref.watch(expenseNotifierProvider);
    final markdownContent = ref.watch(insightsMarkdownProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Insights'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Insights',
            onPressed: _refreshInsights,
          ),
        ],
      ),
      body: expenseState.when(
        data: (state) {
          if (state.expenses.isEmpty) {
            return _buildEmptyState(context);
          }

          return insightsState.when(
            data: (insightsData) {
              if (insightsData.insights == null) {
                return _buildNoInsightsState(context);
              }

              return _buildInsightsContent(context, markdownContent);
            },
            loading: () => _buildLoadingSkeleton(context),
            error: (error, stack) => _buildErrorState(context, error),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading expenses',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insights,
            size: 128,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Data for Insights',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some expenses to generate spending insights',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoInsightsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 128,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Insights Generated',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the refresh button to generate AI-powered insights',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshInsights,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate Insights'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBlock(height: 40, width: double.infinity),
          const SizedBox(height: 16),
          _SkeletonBlock(height: 20, width: 200),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: 300),
          const SizedBox(height: 24),
          _SkeletonBlock(height: 40, width: double.infinity),
          const SizedBox(height: 16),
          _SkeletonBlock(height: 20, width: 150),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
          const SizedBox(height: 24),
          _SkeletonBlock(height: 40, width: double.infinity),
          const SizedBox(height: 16),
          _SkeletonBlock(height: 20, width: 180),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonBlock(height: 16, width: double.infinity),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Insights',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshInsights,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsContent(BuildContext context, String markdownContent) {
    final insightsState = ref.read(insightsNotifierProvider);
    final insights = insightsState.valueOrNull?.insights;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildInsightCard(
            context,
            title: 'Summary',
            icon: Icons.summarize,
            color: Colors.blue,
            child: Text(
              insights?.summary ?? 'No summary available',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),

          // Total Spending Card
          _buildInsightCard(
            context,
            title: 'Total Spending',
            icon: Icons.account_balance_wallet,
            color: Colors.green,
            child: Row(
              children: [
                Text(
                  '\$',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  (insights?.totalSpending ?? 0).toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Top Categories Card
          _buildInsightCard(
            context,
            title: 'Top Spending Categories',
            icon: Icons.bar_chart,
            color: Colors.orange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insights?.topCategories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category.category,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            '\$${category.amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: category.percentage / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category.percentage.toStringAsFixed(1)}% of total',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                );
              }).toList() ??
                  [const Text('No category data available')],
            ),
          ),
          const SizedBox(height: 16),

          // Recommendation Card
          _buildInsightCard(
            context,
            title: 'Recommendation',
            icon: Icons.lightbulb,
            color: Colors.purple,
            child: Text(
              insights?.recommendation ?? 'No recommendation available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(height: 24),

          // Last updated info
          if (insightsState.valueOrNull?.lastGenerated != null)
            Center(
              child: Text(
                'Last updated: ${_formatDateTime(insightsState.valueOrNull!.lastGenerated!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshInsights() async {
    final expenseState = ref.read(expenseNotifierProvider);
    final expenses = expenseState.valueOrNull?.expenses ?? [];

    if (expenses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No expenses to analyze'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Initialize AI service with API key from Hive storage
    final apiKey = StorageService.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your Gemini API key in settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      ref.read(insightsNotifierProvider.notifier).initializeAI(apiKey);
      await ref.read(insightsNotifierProvider.notifier).refreshInsights(expenses);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insights refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh insights: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double width;

  const _SkeletonBlock({
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

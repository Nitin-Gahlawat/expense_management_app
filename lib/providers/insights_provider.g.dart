part of 'insights_provider.dart';

String _$insightsMarkdownHash() => r'8b337aedca19453d1ad43b1a0a6c7d34b46d38c2';

@ProviderFor(insightsMarkdown)
final insightsMarkdownProvider = AutoDisposeProvider<String>.internal(
  insightsMarkdown,
  name: r'insightsMarkdownProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$insightsMarkdownHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef InsightsMarkdownRef = AutoDisposeProviderRef<String>;
String _$insightsNotifierHash() => r'baf916f0a51c720e06e9f4e210caf3a8f5ed1fac';

@ProviderFor(InsightsNotifier)
final insightsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<InsightsNotifier, InsightsState>.internal(
      InsightsNotifier.new,
      name: r'insightsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$insightsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$InsightsNotifier = AutoDisposeAsyncNotifier<InsightsState>;

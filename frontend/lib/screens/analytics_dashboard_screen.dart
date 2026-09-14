import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

/// App Analytics Dashboard available to all users.
///
/// Displays app usage statistics, feature breakdowns, popular destinations,
/// search queries, and recent event logs streaming to Firebase.
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Firebase Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Analytics dashboard refreshed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Insights'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Live Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(colorScheme, theme),
          _buildInsightsTab(colorScheme, theme),
          _buildLiveLogsTab(colorScheme, theme),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ColorScheme colorScheme, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status Banner
          Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    _analytics.isInitialized
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: _analytics.isInitialized ? Colors.green : Colors.amber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _analytics.isInitialized
                              ? 'Firebase Analytics Active'
                              : 'Analytics Standby Mode',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _analytics.isInitialized
                              ? 'Events are streaming to Firebase Console & local metrics.'
                              : 'Local event tracking enabled. Link Firebase config to sync cloud analytics.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Overview KPI Grid
          Text(
            'Usage Summary',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildKpiCard(
                title: 'App Opens',
                value: '${_analytics.appOpensCount}',
                icon: Icons.launch_outlined,
                color: Colors.blue,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'Logins',
                value: '${_analytics.loginCount}',
                icon: Icons.login_outlined,
                color: Colors.green,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'New Signups',
                value: '${_analytics.signUpCount}',
                icon: Icons.person_add_outlined,
                color: Colors.purple,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'Searches',
                value: '${_analytics.searchCount}',
                icon: Icons.search_outlined,
                color: Colors.orange,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'Destination Views',
                value: '${_analytics.destinationViewsCount}',
                icon: Icons.place_outlined,
                color: Colors.teal,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'Itineraries Created',
                value: '${_analytics.itinerariesCreatedCount}',
                icon: Icons.map_outlined,
                color: Colors.indigo,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'Favorites Saved',
                value: '${_analytics.favoritesToggledCount}',
                icon: Icons.favorite_border,
                color: Colors.red,
                colorScheme: colorScheme,
              ),
              _buildKpiCard(
                title: 'Feedback Sent',
                value: '${_analytics.feedbackSubmittedCount}',
                icon: Icons.feedback_outlined,
                color: Colors.amber,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab(ColorScheme colorScheme, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreakdownSection(
            title: 'Most Viewed Destinations',
            icon: Icons.place,
            data: _analytics.viewedDestinations,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildBreakdownSection(
            title: 'Top Search Terms',
            icon: Icons.manage_search,
            data: _analytics.topSearchTerms,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildBreakdownSection(
            title: 'Destination Categories Popularity',
            icon: Icons.category,
            data: _analytics.viewedCategories,
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildBreakdownSection(
            title: 'Itinerary Travel Paces',
            icon: Icons.directions_walk,
            data: _analytics.itineraryPaces,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required IconData icon,
    required Map<String, int> data,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sortedEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No activity recorded yet for this metric.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...sortedEntries.take(5).map((entry) {
                final ratio = entry.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '${entry.value} views',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor:
                              colorScheme.primaryContainer.withValues(alpha: 0.3),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveLogsTab(ColorScheme colorScheme, ThemeData theme) {
    final logs = _analytics.recentEventLogs;
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No events logged in current session.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt, size: 16, color: colorScheme.primary),
          ),
          title: Text(
            log['event'] ?? 'event',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            log['details'] ?? '',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          trailing: Text(
            log['timestamp'] ?? '',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

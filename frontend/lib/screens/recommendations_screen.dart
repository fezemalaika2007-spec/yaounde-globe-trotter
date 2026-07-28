import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class RecommendationsScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const RecommendationsScreen({super.key, required this.onLocaleChanged});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _api = ApiService();
  List<dynamic> _recommendations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getRecommendations();
      if (mounted) setState(() => _recommendations = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to load recommendations');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Refresh button row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.refresh),
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _fetch, child: Text(l10n.refresh)),
                    ],
                  ),
                )
              : _recommendations.isEmpty
              ? Center(child: Text(l10n.noRecommendations))
              : ListView.builder(
                  itemCount: _recommendations.length,
                  itemBuilder: (_, i) {
                    final r = _recommendations[i];
                    final score = r['match_score'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: score > 0
                              ? Colors.green
                              : Colors.grey,
                          child: Text('$score'),
                        ),
                        title: Text(r['name'] ?? ''),
                        subtitle: Text(
                          '${r['country']} · ${r['continent']}\n'
                          '\$${r['avg_cost_per_day']}/day · '
                          '${(r['tags'] as List).join(', ')}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

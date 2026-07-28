import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const HomeScreen({super.key, required this.onLocaleChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _tagCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  List<dynamic> _destinations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      int? maxCost;
      if (_costCtrl.text.trim().isNotEmpty) {
        maxCost = int.tryParse(_costCtrl.text.trim());
      }

      final data = await _api.getDestinations(
        tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
        maxCost: maxCost,
      );
      if (mounted) setState(() => _destinations = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to load destinations');
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
        // --- Filter bar ---
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.tagFilter,
                    hintText: 'e.g. beach',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.maxCost,
                    hintText: 'e.g. 150',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _fetch,
                tooltip: l10n.search,
              ),
            ],
          ),
        ),
        // --- Results ---
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
              : _destinations.isEmpty
              ? Center(child: Text(l10n.noDestinations))
              : ListView.builder(
                  itemCount: _destinations.length,
                  itemBuilder: (_, i) {
                    final d = _destinations[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text((d['name'] as String)[0].toUpperCase()),
                        ),
                        title: Text(d['name'] ?? ''),
                        subtitle: Text(
                          '${d['country']} · ${d['continent']}\n'
                          '\$${d['avg_cost_per_day']}/${l10n.avgCostPerDay.toLowerCase()} · '
                          '${(d['tags'] as List).join(', ')}',
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

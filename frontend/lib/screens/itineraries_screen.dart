import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class ItinerariesScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const ItinerariesScreen({super.key, required this.onLocaleChanged});

  @override
  State<ItinerariesScreen> createState() => _ItinerariesScreenState();
}

class _ItinerariesScreenState extends State<ItinerariesScreen> {
  final _api = ApiService();
  List<dynamic> _itineraries = [];
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
      final data = await _api.getItineraries();
      if (mounted) setState(() => _itineraries = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load itineraries');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCreateForm() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateItineraryDialog(onCreated: _fetch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        Column(
          children: [
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _fetch,
                            child: Text(l10n.refresh),
                          ),
                        ],
                      ),
                    )
                  : _itineraries.isEmpty
                  ? Center(child: Text(l10n.noItineraries))
                  : ListView.builder(
                      itemCount: _itineraries.length,
                      itemBuilder: (_, i) {
                        final it = _itineraries[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.map, color: Colors.blue),
                            title: Text(it['title'] ?? ''),
                            subtitle: Text(
                              '${(it['destinations'] as List).join(', ')}\n'
                              '${it['start_date']} \u2192 ${it['end_date']}\n'
                              '${it['notes'] ?? ''}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _openCreateForm,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create Itinerary Dialog
// ---------------------------------------------------------------------------

class _CreateItineraryDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateItineraryDialog({required this.onCreated});

  @override
  State<_CreateItineraryDialog> createState() => _CreateItineraryDialogState();
}

class _CreateItineraryDialogState extends State<_CreateItineraryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _destinationsCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _destinationsCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final destinations = _destinationsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await ApiService().createItinerary(
        title: _titleCtrl.text.trim(),
        destinations: destinations,
        startDate: _startCtrl.text.trim(),
        endDate: _endCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
      widget.onCreated();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to create itinerary');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Itinerary'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Destinations (comma-separated)',
                  hintText: 'Bali, Santorini',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Start date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endCtrl,
                decoration: const InputDecoration(
                  labelText: 'End date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

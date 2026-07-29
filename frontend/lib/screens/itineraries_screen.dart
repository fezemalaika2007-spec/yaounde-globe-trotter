import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/image_paths.dart';
import '../widgets/asset_image.dart';
import '../widgets/empty_state.dart';

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
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n.yourItineraries,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
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
                          Icon(
                            Icons.cloud_off,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _fetch,
                            child: Text(l10n.tryAgain),
                          ),
                        ],
                      ),
                    )
                  : _itineraries.isEmpty
                  ? EmptyState(
                      icon: Icons.map_outlined,
                      title: l10n.noItineraries,
                      message: l10n.createFirstItinerary,
                      onAction: _openCreateForm,
                      actionLabel: l10n.createItinerary,
                    )
                  : ListView.builder(
                      itemCount: _itineraries.length,
                      padding: const EdgeInsets.only(top: 4, bottom: 88),
                      itemBuilder: (_, i) {
                        final it = _itineraries[i];
                        // Use a small representative image based on index
                        final imageIndex = i % 6;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Small representative image
                              SizedBox(
                                width: 100,
                                height: 140,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: AssetImageWidget(
                                    path: ImagePaths.destination(imageIndex),
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.map_outlined,
                                  ),
                                ),
                              ),
                              // Content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.map,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              it['title'] ?? '',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${it['start_date']} \u2192 ${it['end_date']}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: (it['destinations'] as List)
                                            .map(
                                              (d) => Chip(
                                                label: Text(
                                                  '$d',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                padding: EdgeInsets.zero,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      if ((it['notes'] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          it['notes'],
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontStyle: FontStyle.italic,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
// Create Itinerary Dialog with Date Pickers
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

  Future<void> _pickDate(TextEditingController ctrl) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      ctrl.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.newItinerary),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.title,
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.enterTitle : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationsCtrl,
                decoration: InputDecoration(
                  labelText: l10n.destinationsList,
                  hintText: 'Mont Fébé, Mvog-Betsi',
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.enterDestinations
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: l10n.startDate,
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () => _pickDate(_startCtrl),
                  ),
                ),
                onTap: () => _pickDate(_startCtrl),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: l10n.endDate,
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () => _pickDate(_endCtrl),
                  ),
                ),
                onTap: () => _pickDate(_endCtrl),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.notes,
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.create),
        ),
      ],
    );
  }
}

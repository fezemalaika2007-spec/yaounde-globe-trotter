import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
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
      builder: (ctx) => _ItineraryFormDialog(
        onSaved: _fetch,
        mode: _FormMode.create,
      ),
    );
  }

  void _openEditForm(Map<String, dynamic> itinerary) {
    showDialog(
      context: context,
      builder: (ctx) => _ItineraryFormDialog(
        onSaved: _fetch,
        mode: _FormMode.edit,
        existing: itinerary,
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> itinerary) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 48, color: theme.colorScheme.error),
        title: const Text('Delete Itinerary'),
        content: Text(
          'Are you sure you want to delete "${itinerary['title']}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deleteItinerary(id: itinerary['id'].toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${itinerary['title']}" deleted'),
            ),
          );
          _fetch();
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: ${e.message}')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete itinerary')),
          );
        }
      }
    }
  }

  /// Computes a human-readable trip duration string.
  String _tripDuration(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return '';
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final days = end.difference(start).inDays + 1;
      if (days <= 0) return '';
      return days == 1 ? '1 day' : '$days days';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.map,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.yourItineraries,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_loading && _itineraries.isNotEmpty)
                          Text(
                            '${_itineraries.length} trip${_itineraries.length == 1 ? '' : 's'} planned',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
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
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
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
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: ListView.builder(
                        itemCount: _itineraries.length,
                        padding: const EdgeInsets.only(top: 4, bottom: 88),
                        itemBuilder: (_, i) {
                          final it =
                              Map<String, dynamic>.from(_itineraries[i]);
                          return _buildItineraryCard(it, theme, l10n);
                        },
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add),
            label: Text(l10n.createItinerary),
          ),
        ),
      ],
    );
  }

  Widget _buildItineraryCard(
    Map<String, dynamic> it,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final dests = (it['destinations'] as List?) ?? [];
    final duration = _tripDuration(it['start_date'], it['end_date']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.map,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    it['title'] ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Edit button
                IconButton(
                  onPressed: () => _openEditForm(it),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(it),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Date and duration row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${it['start_date']} \u2192 ${it['end_date']}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        duration,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Destination chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: dests
                  .map(
                    (d) => Chip(
                      avatar: Icon(
                        Icons.place,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(
                        '$d',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
            if ((it['notes'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        it['notes'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Form Mode Enum
// ---------------------------------------------------------------------------

enum _FormMode { create, edit }

// ---------------------------------------------------------------------------
// Create / Edit Itinerary Dialog with Date Pickers
// ---------------------------------------------------------------------------

class _ItineraryFormDialog extends StatefulWidget {
  final VoidCallback onSaved;
  final _FormMode mode;
  final Map<String, dynamic>? existing;

  const _ItineraryFormDialog({
    required this.onSaved,
    required this.mode,
    this.existing,
  });

  @override
  State<_ItineraryFormDialog> createState() => _ItineraryFormDialogState();
}

class _ItineraryFormDialogState extends State<_ItineraryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _destinationsCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.mode == _FormMode.edit && widget.existing != null) {
      final e = widget.existing!;
      _titleCtrl.text = e['title'] ?? '';
      final dests = (e['destinations'] as List?) ?? [];
      _destinationsCtrl.text = dests.join(', ');
      _startCtrl.text = e['start_date'] ?? '';
      _endCtrl.text = e['end_date'] ?? '';
      _notesCtrl.text = e['notes'] ?? '';
    }
  }

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

      if (widget.mode == _FormMode.create) {
        await ApiService().createItinerary(
          title: _titleCtrl.text.trim(),
          destinations: destinations,
          startDate: _startCtrl.text.trim(),
          endDate: _endCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );
      } else {
        await ApiService().updateItinerary(
          id: widget.existing!['id'].toString(),
          title: _titleCtrl.text.trim(),
          destinations: destinations,
          startDate: _startCtrl.text.trim(),
          endDate: _endCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
      widget.onSaved();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = widget.mode == _FormMode.create
          ? 'Failed to create itinerary'
          : 'Failed to update itinerary');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEdit = widget.mode == _FormMode.edit;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit : Icons.add_circle_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Itinerary' : l10n.newItinerary),
        ],
      ),
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
              : Text(isEdit ? l10n.save : l10n.create),
        ),
      ],
    );
  }
}

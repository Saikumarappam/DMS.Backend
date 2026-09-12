import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

class HistoryDateFilterResult {
  const HistoryDateFilterResult({
    this.fromDate,
    this.toDate,
  });

  final DateTime? fromDate;
  final DateTime? toDate;

  bool get hasFilter => fromDate != null || toDate != null;
}

Future<HistoryDateFilterResult?> showHistoryDateFilterSheet({
  required BuildContext context,
  DateTime? initialFromDate,
  DateTime? initialToDate,
}) {
  return showModalBottomSheet<HistoryDateFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _HistoryDateFilterSheet(
      initialFromDate: initialFromDate,
      initialToDate: initialToDate,
    ),
  );
}

class _HistoryDateFilterSheet extends StatefulWidget {
  const _HistoryDateFilterSheet({
    this.initialFromDate,
    this.initialToDate,
  });

  final DateTime? initialFromDate;
  final DateTime? initialToDate;

  @override
  State<_HistoryDateFilterSheet> createState() => _HistoryDateFilterSheetState();
}

class _HistoryDateFilterSheetState extends State<_HistoryDateFilterSheet> {
  DateTime? _fromDate;
  DateTime? _toDate;
  final _dayFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select start date',
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = null;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final minDate = _fromDate ?? DateTime(2020);
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: minDate,
      lastDate: DateTime.now(),
      helpText: 'Select end date (optional)',
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
      ),
      child: child!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Date range',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start date is required. End date is optional.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Start date',
            value: _fromDate != null ? _dayFormat.format(_fromDate!) : 'Select start date',
            onTap: _pickFromDate,
            isSet: _fromDate != null,
          ),
          const SizedBox(height: 10),
          _DateField(
            label: 'End date (optional)',
            value: _toDate != null ? _dayFormat.format(_toDate!) : 'No end date',
            onTap: _pickToDate,
            isSet: _toDate != null,
            trailing: _toDate != null
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _toDate = null),
                    tooltip: 'Clear end date',
                  )
                : null,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _fromDate == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            HistoryDateFilterResult(fromDate: _fromDate, toDate: _toDate),
                          ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.isSet,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isSet;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sky),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSet ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

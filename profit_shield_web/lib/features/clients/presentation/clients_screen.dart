import 'package:flutter/material.dart';
import 'package:profit_shield_web/features/user_approvals/presentation/widgets/admin_password_dialog.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/admin_shell.dart';
import '../models/client_model.dart';
import '../providers/clients_provider.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientsProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientsProvider>();

    return AdminShell(
      selectedLabel: 'Clients',
      title: 'Clients',
      isLoading: provider.isLoading && provider.filteredClients.isEmpty,
      onRefresh: () => provider.load(),
      child: RefreshIndicator(
        onRefresh: () => provider.load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (provider.errorMessage != null)
                _MessageBanner(message: provider.errorMessage!, isError: true),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _ClientsSearchBar(
                        searchController: _searchController,
                        onSearchChanged: provider.setSearch,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (provider.isLoading && provider.filteredClients.isEmpty)
                      const SizedBox(height: 280)
                    else
                      _ClientsTable(
                        clients: provider.pagedClients,
                        startIndex:
                            (provider.currentPage - 1) *
                            ClientsProvider.pageSize,
                        onView: (client) =>
                            _showClientDialog(context, client, editable: false),
                        onEdit: (client) =>
                            _showClientDialog(context, client, editable: true),
                      ),
                    _ClientsPaginationBar(
                      currentPage: provider.currentPage,
                      totalPages: provider.totalPages,
                      totalItems: provider.filteredClients.length,
                      pageSize: ClientsProvider.pageSize,
                      onPageChanged: provider.setPage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClientDialog(
    BuildContext context,
    ClientListItem client, {
    required bool editable,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _ClientDetailsDialog(client: client, editable: editable),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? AppColors.danger : AppColors.success).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isError ? AppColors.danger : AppColors.success).withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? AppColors.danger : AppColors.success,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ClientsSearchBar extends StatelessWidget {
  const _ClientsSearchBar({
    required this.searchController,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  static const double _searchWidth = 260;

  @override
  Widget build(BuildContext context) {
    // Align prevents the parent Column's CrossAxisAlignment.stretch
    // from forcing the search field to full width.
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        // width: _searchWidth,
        width: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width *
                  0.8 // // Mobile
            : MediaQuery.of(context).size.width < 1024
            ? MediaQuery.of(context).size.width *
                  0.6 // Tablet
            : MediaQuery.of(context).size.width * 0.4, // Desktop
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search clients by name, GSTIN, mobile...',
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientsTable extends StatelessWidget {
  const _ClientsTable({
    required this.clients,
    required this.startIndex,
    required this.onView,
    required this.onEdit,
  });

  final List<ClientListItem> clients;
  final int startIndex;
  final ValueChanged<ClientListItem> onView;
  final ValueChanged<ClientListItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columnSpacing: 24,
              headingTextStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Client Name')),
                DataColumn(label: Text('GSTIN')),
                DataColumn(label: Text('Mobile')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Pending Tasks')),
                DataColumn(label: Text('Action')),
              ],
              rows: clients.isEmpty
                  ? [
                      const DataRow(
                        cells: [
                          DataCell(Text('—')),
                          DataCell(Text('No clients found')),
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(SizedBox.shrink()),
                        ],
                      ),
                    ]
                  : [
                      for (var i = 0; i < clients.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${startIndex + i + 1}')),
                            DataCell(
                              Text(
                                clients[i].clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(Text(clients[i].gstinDisplay)),
                            DataCell(Text(clients[i].mobileNumber)),
                            DataCell(
                              _ClientStatusChip(isActive: clients[i].isActive),
                            ),
                            DataCell(
                              Text(
                                '${clients[i].pendingTasks}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: clients[i].pendingTasks > 0
                                      ? AppColors.danger
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'View',
                                    onPressed: () => onView(clients[i]),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => onEdit(clients[i]),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
            ),
          ),
        );
      },
    );
  }
}

class _ClientStatusChip extends StatelessWidget {
  const _ClientStatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.danger;
    final label = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClientsPaginationBar extends StatelessWidget {
  const _ClientsPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) {
      return const SizedBox(height: 16);
    }

    final start = ((currentPage - 1) * pageSize) + 1;
    final end = (currentPage * pageSize).clamp(0, totalItems);
    final visiblePages = totalPages <= 5
        ? List.generate(totalPages, (index) => index + 1)
        : _visiblePageNumbers(currentPage, totalPages);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Text(
            'Showing $start to $end of $totalItems clients',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          for (final page in visiblePages) ...[
            if (page == -1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…', style: TextStyle(color: AppColors.textMuted)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  onPressed: () => onPageChanged(page),
                  style: TextButton.styleFrom(
                    backgroundColor: page == currentPage
                        ? AppColors.success.withValues(alpha: 0.12)
                        : null,
                    side: page == currentPage
                        ? const BorderSide(color: AppColors.success)
                        : null,
                    minimumSize: const Size(36, 36),
                  ),
                  child: Text('$page'),
                ),
              ),
          ],
          IconButton(
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  List<int> _visiblePageNumbers(int current, int total) {
    if (total <= 5) {
      return List.generate(total, (index) => index + 1);
    }
    if (current <= 3) return [1, 2, 3, -1, total];
    if (current >= total - 2) return [1, -1, total - 2, total - 1, total];
    return [1, -1, current, -1, total];
  }
}

class _ClientDetailsDialog extends StatefulWidget {
  const _ClientDetailsDialog({required this.client, required this.editable});

  final ClientListItem client;
  final bool editable;

  @override
  State<_ClientDetailsDialog> createState() => _ClientDetailsDialogState();
}

class _ClientDetailsDialogState extends State<_ClientDetailsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _businessController;
  late final TextEditingController _contactController;
  late final TextEditingController _gstController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late bool _isActive;
  var _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client.name);
    _businessController = TextEditingController(text: client.businessName);
    _contactController = TextEditingController(text: client.contactPersonName);
    _gstController = TextEditingController(
      text: client.gstinDisplay == '—' ? '' : client.gstinDisplay,
    );
    _mobileController = TextEditingController(text: client.mobileNumber);
    _emailController = TextEditingController(text: client.email);
    _addressController = TextEditingController(text: client.address);
    _isActive = client.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _contactController.dispose();
    _gstController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _save() async {
    if (!await showAdminPasswordDialog(context)) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || mobile.isEmpty || email.isEmpty) {
      setState(() => _errorText = 'Name, mobile, and email are required.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final profile = ClientProfileUpdate(
      name: name,
      mobileNumber: mobile,
      email: email,
      address: _addressController.text.trim(),
      businessName: _businessController.text.trim(),
      contactPersonName: _contactController.text.trim(),
      gstNumber: _gstController.text.trim(),
      profileCompleted: widget.client.profileCompleted,
    );

    final error = await context.read<ClientsProvider>().updateClient(
      client: widget.client,
      profile: profile,
      isActive: _isActive,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _errorText = error;
      });

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Failed'),
          content: Text(error),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Client updated successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(widget.editable ? 'Edit Client' : 'Client Details'),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: widget.editable
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: _fieldDecoration('Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _businessController,
                      enabled: !_saving,
                      decoration: _fieldDecoration('Business Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactController,
                      enabled: !_saving,
                      decoration: _fieldDecoration('Contact Person'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _gstController,
                      enabled: !_saving,
                      decoration: _fieldDecoration('GSTIN'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileController,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDecoration('Mobile'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration('Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      enabled: !_saving,
                      maxLines: 2,
                      decoration: _fieldDecoration('Address'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool>(
                      value: _isActive,
                      decoration: _fieldDecoration('Status'),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Active')),
                        DropdownMenuItem(value: false, child: Text('Inactive')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null)
                                setState(() => _isActive = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'PAN',
                      value: client.panNumber.isEmpty ? '—' : client.panNumber,
                    ),
                    _DetailRow(
                      label: 'Pending Tasks',
                      value: '${client.pendingTasks}',
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Name', value: client.name),
                    _DetailRow(
                      label: 'Business Name',
                      value: client.businessName,
                    ),
                    _DetailRow(
                      label: 'Contact Person',
                      value: client.contactPersonName,
                    ),
                    _DetailRow(label: 'GSTIN', value: client.gstinDisplay),
                    _DetailRow(
                      label: 'PAN',
                      value: client.panNumber.isEmpty ? '—' : client.panNumber,
                    ),
                    _DetailRow(label: 'Mobile', value: client.mobileNumber),
                    _DetailRow(
                      label: 'Email',
                      value: client.email.isEmpty ? '—' : client.email,
                    ),
                    _DetailRow(
                      label: 'Address',
                      value: client.address.isEmpty ? '—' : client.address,
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: client.isActive ? 'Active' : 'Inactive',
                    ),
                    _DetailRow(
                      label: 'Pending Tasks',
                      value: '${client.pendingTasks}',
                    ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(widget.editable ? 'Cancel' : 'Close'),
        ),
        if (widget.editable)
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

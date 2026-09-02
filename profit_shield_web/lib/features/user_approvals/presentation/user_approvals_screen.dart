import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../dashboard/presentation/widgets/admin_shell.dart';
import '../models/approval_user_model.dart';
import '../providers/user_approvals_provider.dart';
import 'widgets/admin_password_dialog.dart';

class UserApprovalsScreen extends StatefulWidget {
  const UserApprovalsScreen({super.key});

  @override
  State<UserApprovalsScreen> createState() => _UserApprovalsScreenState();
}

class _UserApprovalsScreenState extends State<UserApprovalsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserApprovalsProvider>().load(
        status: UserApprovalStatus.pending,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _pageTitle(UserApprovalStatus status) {
    final width = MediaQuery.sizeOf(context).width;
    final short = width < Breakpoints.desktop;

    switch (status) {
      case UserApprovalStatus.pending:
        return short
            ? 'User Approvals · Pending'
            : 'User Approval Requests - Pending';
      case UserApprovalStatus.approved:
        return short
            ? 'User Approvals · Approved'
            : 'User Approval Requests - Approved';
      case UserApprovalStatus.rejected:
        return short
            ? 'User Approvals · Rejected'
            : 'User Approval Requests - Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserApprovalsProvider>();

    return AdminShell(
      selectedLabel: 'User Approvals',
      title: _pageTitle(provider.activeStatus),
      isLoading: provider.isLoading && provider.users.isEmpty,
      onRefresh: () => provider.load(),
      child: RefreshIndicator(
        onRefresh: () => provider.load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (provider.actionMessage != null)
                _MessageBanner(
                  message: provider.actionMessage!,
                  isError: false,
                ),
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
                    _StatusTabs(
                      active: provider.activeStatus,
                      counts: provider.counts,
                      onChanged: (status) {
                        _searchController.clear();
                        provider.load(status: status, search: '');
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _SearchFilterBar(
                        controller: _searchController,
                        onChanged: provider.setSearch,
                        onFilter: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Use tabs and search to filter users.',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (provider.isLoading && provider.users.isEmpty)
                      const SizedBox(height: 280)
                    else
                      _UsersTable(
                        status: provider.activeStatus,
                        users: provider.pagedUsers,
                        startIndex:
                            (provider.currentPage - 1) *
                            UserApprovalsProvider.pageSize,
                        onApprove: (user) => _confirmApprove(context, user),
                        onReject: (user) => _confirmReject(context, user),
                        onEdit: (user) => _showEditDialog(context, user),
                        onView: (user) => _showViewDialog(context, user),
                      ),
                    _PaginationBar(
                      currentPage: provider.currentPage,
                      totalPages: provider.totalPages,
                      totalItems: provider.users.length,
                      pageSize: UserApprovalsProvider.pageSize,
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

  Future<void> _confirmApprove(BuildContext context, ApprovalUser user) async {
    if (!await showAdminPasswordDialog(context)) return;
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve User'),
        content: Text('Approve ${user.name} (${user.businessName})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final error = await context.read<UserApprovalsProvider>().approve(
      user.userId,
    );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User approved successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmReject(BuildContext context, ApprovalUser user) async {
    if (!await showAdminPasswordDialog(context)) return;
    if (!context.mounted) return;

    final commentsController = TextEditingController();
    var comments = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${user.name}?'),
            const SizedBox(height: 12),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Comments (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              comments = commentsController.text;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    commentsController.dispose();
    if (ok != true || !context.mounted) return;

    final error = await context.read<UserApprovalsProvider>().reject(
      user.userId,
      comments: comments,
    );
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User rejected.'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _showViewDialog(BuildContext context, ApprovalUser user) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _UserDetailsDialog(user: user, editable: false),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ApprovalUser user) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _UserDetailsDialog(user: user, editable: true),
    );
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
        style: TextStyle(color: isError ? AppColors.danger : AppColors.success),
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.active,
    required this.counts,
    required this.onChanged,
  });

  final UserApprovalStatus active;
  final UserApprovalCounts counts;
  final ValueChanged<UserApprovalStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _TabButton(
            label: 'Pending (${counts.pending})',
            selected: active == UserApprovalStatus.pending,
            onTap: () => onChanged(UserApprovalStatus.pending),
          ),
          _TabButton(
            label: 'Approved (${counts.approved})',
            selected: active == UserApprovalStatus.approved,
            onTap: () => onChanged(UserApprovalStatus.approved),
          ),
          _TabButton(
            label: 'Rejected (${counts.rejected})',
            selected: active == UserApprovalStatus.rejected,
            onTap: () => onChanged(UserApprovalStatus.rejected),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.success : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.success : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.controller,
    required this.onChanged,
    required this.onFilter,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.width *
                    0.8 // // Mobile
              : MediaQuery.of(context).size.width < 1024
              ? MediaQuery.of(context).size.width *
                    0.6 // Tablet
              : MediaQuery.of(context).size.width * 0.4, // Desktop
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, business name or mobile...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
        // const SizedBox(width: 12),
        // OutlinedButton.icon(
        //   onPressed: onFilter,
        //   icon: const Icon(Icons.filter_list, size: 18),
        //   label: const Text('Filter'),
        //   style: OutlinedButton.styleFrom(
        //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        //     side: const BorderSide(color: AppColors.border),
        //     foregroundColor: AppColors.textPrimary,
        //   ),
        // ),
      ],
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.status,
    required this.users,
    required this.startIndex,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onView,
  });

  final UserApprovalStatus status;
  final List<ApprovalUser> users;
  final int startIndex;
  final ValueChanged<ApprovalUser> onApprove;
  final ValueChanged<ApprovalUser> onReject;
  final ValueChanged<ApprovalUser> onEdit;
  final ValueChanged<ApprovalUser> onView;

  String _dateLabel() {
    switch (status) {
      case UserApprovalStatus.pending:
        return 'Requested On';
      case UserApprovalStatus.approved:
        return 'Approved On';
      case UserApprovalStatus.rejected:
        return 'Rejected On';
    }
  }

  String _formatDate(ApprovalUser user) {
    final date = status == UserApprovalStatus.pending
        ? user.createdDate
        : user.modifiedDate;
    if (date == null) return '—';
    return DateFormat('dd MMM yyyy').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  minHeight: users.isEmpty ? 120 : 0,
                ),
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 72,
                  columnSpacing: 20,
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  columns: [
                    const DataColumn(label: Text('#')),
                    const DataColumn(label: Text('Name')),
                    const DataColumn(label: Text('Business Name')),
                    const DataColumn(label: Text('Mobile')),
                    DataColumn(label: Text(_dateLabel())),
                    const DataColumn(label: Text('Status')),
                    const DataColumn(label: Text('Action')),
                  ],
                  //           rows: users.isEmpty
                  //               ? [
                  //                   const DataRow(
                  //                     cells: [
                  //                       DataCell(Text('—')),
                  //                       DataCell(Text('No users found')),
                  //                       DataCell(Text('—')),
                  //                       DataCell(Text('—')),
                  //                       DataCell(Text('—')),
                  //                       DataCell(Text('—')),
                  //                       DataCell(SizedBox.shrink()),
                  //                     ],
                  //                   ),
                  //                 ]
                  //               : [
                  //                   for (var i = 0; i < users.length; i++)
                  //                     DataRow(
                  //                       cells: [
                  //                         DataCell(Text('${startIndex + i + 1}')),
                  //                         DataCell(
                  //                           Text(
                  //                             users[i].name,
                  //                             style: const TextStyle(
                  //                               fontWeight: FontWeight.w600,
                  //                             ),
                  //                           ),
                  //                         ),
                  //                         DataCell(Text(users[i].businessName)),
                  //                         DataCell(Text(users[i].mobileNumber)),
                  //                         DataCell(Text(_formatDate(users[i]))),
                  //                         DataCell(_StatusChip(status: users[i].userStatus)),
                  //                         DataCell(
                  //                           SizedBox(
                  //                             width: _actionColumnWidth(status),
                  //                             child: Align(
                  //                               alignment: Alignment.centerLeft,
                  //                               child: _ActionButtons(
                  //                                 status: status,
                  //                                 onApprove: () => onApprove(users[i]),
                  //                                 onReject: () => onReject(users[i]),
                  //                                 onEdit: () => onEdit(users[i]),
                  //                                 onView: () => onView(users[i]),
                  //                               ),
                  //                             ),
                  //                           ),
                  //                         ),
                  //                       ],
                  //                     ),
                  //                 ],
                  //         ),
                  //       ),
                  //     ),
                  rows: [
                    if (users.isNotEmpty)
                      for (var i = 0; i < users.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${startIndex + i + 1}')),
                            DataCell(
                              Text(
                                users[i].name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(Text(users[i].businessName)),
                            DataCell(Text(users[i].mobileNumber)),
                            DataCell(Text(_formatDate(users[i]))),
                            DataCell(_StatusChip(status: users[i].userStatus)),
                            DataCell(
                              SizedBox(
                                width: _actionColumnWidth(status),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _ActionButtons(
                                    status: status,
                                    onApprove: () => onApprove(users[i]),
                                    onReject: () => onReject(users[i]),
                                    onEdit: () => onEdit(users[i]),
                                    onView: () => onView(users[i]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),

            if (users.isEmpty)
              Column(
                children: [
                  SizedBox(height: 40),
                  const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  double _actionColumnWidth(UserApprovalStatus status) {
    switch (status) {
      case UserApprovalStatus.pending:
        return 220;
      case UserApprovalStatus.approved:
        return 180;
      case UserApprovalStatus.rejected:
        return 100;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color bg;
    Color fg;
    switch (normalized) {
      case 'approved':
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        break;
      case 'rejected':
        bg = AppColors.danger.withValues(alpha: 0.12);
        fg = AppColors.danger;
        break;
      default:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onView,
  });

  final UserApprovalStatus status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case UserApprovalStatus.pending:
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ApproveButton(onPressed: onApprove),
            _RejectButton(onPressed: onReject),
          ],
        );
      case UserApprovalStatus.approved:
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _OutlineButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
            _OutlineButton(
              label: 'View',
              icon: Icons.visibility_outlined,
              onPressed: onView,
            ),
          ],
        );
      case UserApprovalStatus.rejected:
        return _OutlineButton(
          label: 'View',
          icon: Icons.visibility_outlined,
          onPressed: onView,
        );
    }
  }
}

class _ApproveButton extends StatelessWidget {
  const _ApproveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.check, size: 14, color: AppColors.success),
      label: const Text('Approve'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.success,
        backgroundColor: AppColors.success.withValues(alpha: 0.08),
        side: const BorderSide(color: AppColors.success),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RejectButton extends StatelessWidget {
  const _RejectButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.cancel_outlined,
        size: 14,
        color: AppColors.danger,
      ),
      label: const Text('Reject'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        backgroundColor: AppColors.danger.withValues(alpha: 0.06),
        side: const BorderSide(color: AppColors.danger),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Text(
            'Showing $start to $end of $totalItems requests',
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
          for (var page = 1; page <= totalPages && page <= 5; page++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextButton(
                onPressed: () => onPageChanged(page),
                style: TextButton.styleFrom(
                  backgroundColor: page == currentPage
                      ? AppColors.navy.withValues(alpha: 0.08)
                      : null,
                  minimumSize: const Size(36, 36),
                ),
                child: Text('$page'),
              ),
            ),
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
}

class _UserDetailsDialog extends StatefulWidget {
  const _UserDetailsDialog({required this.user, required this.editable});

  final ApprovalUser user;
  final bool editable;

  @override
  State<_UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<_UserDetailsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _businessController;
  late final TextEditingController _mobileController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _businessController = TextEditingController(text: widget.user.businessName);
    _mobileController = TextEditingController(text: widget.user.mobileNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(widget.editable ? 'Edit User Details' : 'User Details'),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: widget.editable
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _businessController,
                    decoration: const InputDecoration(
                      labelText: 'Business Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mobileController,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'Name', value: user.name),
                  _DetailRow(label: 'Business Name', value: user.businessName),
                  _DetailRow(label: 'Mobile', value: user.mobileNumber),
                  _DetailRow(label: 'Email', value: user.email),
                  _DetailRow(label: 'PAN', value: user.panNumber),
                  _DetailRow(label: 'Status', value: user.userStatus),
                  _DetailRow(
                    label: 'Requested On',
                    value: user.createdDate != null
                        ? DateFormat(
                            'dd MMM yyyy',
                          ).format(user.createdDate!.toLocal())
                        : '—',
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.editable)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'User update will be available when admin edit API is enabled.',
                  ),
                ),
              );
            },
            child: const Text('Update'),
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
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

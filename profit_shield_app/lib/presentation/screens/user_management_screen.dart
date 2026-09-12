import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_models.dart';
import '../../data/repositories/user_repository.dart';
import '../widgets/app_drawer.dart';
import '../widgets/loading_overlay.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;
  String? _statusFilter;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref.read(userRepositoryProvider).getUsers(
          status: _statusFilter,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
        );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _users = result.data ?? [];
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _approveUser(UserModel user) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final commentsController = TextEditingController();

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve ${user.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentsController,
                decoration: const InputDecoration(labelText: 'Comments (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) return;

    final result = await ref.read(userRepositoryProvider).approveReject(
          user.userId,
          UserApprovalRequest(
            action: 'Approve',
            username: usernameController.text.trim(),
            password: passwordController.text,
            comments: commentsController.text.trim().isEmpty
                ? null
                : commentsController.text.trim(),
          ),
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success ? 'User approved' : result.errorMessage),
      ),
    );
    if (result.success) await _loadUsers();
  }

  Future<void> _rejectUser(UserModel user) async {
    final commentsController = TextEditingController();
    final rejected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${user.name}'),
        content: TextField(
          controller: commentsController,
          decoration: const InputDecoration(labelText: 'Comments (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (rejected != true || !mounted) return;

    final result = await ref.read(userRepositoryProvider).approveReject(
          user.userId,
          UserApprovalRequest(
            action: 'Reject',
            comments: commentsController.text.trim().isEmpty
                ? null
                : commentsController.text.trim(),
          ),
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success ? 'User rejected' : result.errorMessage),
      ),
    );
    if (result.success) await _loadUsers();
  }

  Future<void> _toggleStatus(UserModel user) async {
    final result = await ref.read(userRepositoryProvider).setStatus(
          user.userId,
          !user.isActive,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'User ${user.isActive ? 'deactivated' : 'activated'}'
              : result.errorMessage,
        ),
      ),
    );
    if (result.success) await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      drawer: const AppDrawer(isAdmin: true),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth > 600 ? 260 : double.infinity,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search users',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _loadUsers(),
                        ),
                      ),
                      DropdownButton<String?>(
                        value: _statusFilter,
                        hint: const Text('Status filter'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                        ],
                        onChanged: (v) {
                          setState(() => _statusFilter = v);
                          _loadUsers();
                        },
                      ),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: _users.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No users found')),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          child: Text(
                                            user.name.isNotEmpty
                                                ? user.name[0].toUpperCase()
                                                : '?',
                                          ),
                                        ),
                                        title: Text(user.name),
                                        subtitle: Text(
                                          '${user.email} • ${user.mobileNumber}\n'
                                          '${user.roleName} • ${user.userStatus}',
                                        ),
                                        trailing: Chip(
                                          label: Text(
                                            user.isActive ? 'Active' : 'Inactive',
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (user.userStatus == 'Pending') ...[
                                            ElevatedButton(
                                              onPressed: () => _approveUser(user),
                                              child: const Text('Approve'),
                                            ),
                                            OutlinedButton(
                                              onPressed: () => _rejectUser(user),
                                              child: const Text('Reject'),
                                            ),
                                          ],
                                          OutlinedButton(
                                            onPressed: () => _toggleStatus(user),
                                            child: Text(
                                              user.isActive ? 'Deactivate' : 'Activate',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

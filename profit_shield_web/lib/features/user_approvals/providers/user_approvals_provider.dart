import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/user_approvals_repository.dart';
import '../models/approval_user_model.dart';

class UserApprovalsProvider extends ChangeNotifier {
  UserApprovalsProvider(this._repository);

  final UserApprovalsRepository _repository;

  static const pageSize = 8;

  UserApprovalStatus activeStatus = UserApprovalStatus.pending;
  String searchQuery = '';
  UserApprovalCounts counts = UserApprovalCounts.empty();
  List<ApprovalUser> users = [];
  int currentPage = 1;
  bool isLoading = false;
  String? errorMessage;
  String? actionMessage;
  Timer? _searchDebounce;

  int get totalPages {
    if (users.isEmpty) return 1;
    return (users.length / pageSize).ceil();
  }

  List<ApprovalUser> get pagedUsers {
    if (users.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, users.length);
    if (start >= users.length) return const [];
    return users.sublist(start, end);
  }

  int countFor(UserApprovalStatus status) {
    switch (status) {
      case UserApprovalStatus.pending:
        return counts.pending;
      case UserApprovalStatus.approved:
        return counts.approved;
      case UserApprovalStatus.rejected:
        return counts.rejected;
    }
  }

  Future<void> load({UserApprovalStatus? status, String? search}) async {
    if (status != null) activeStatus = status;
    if (search != null) searchQuery = search;

    isLoading = true;
    errorMessage = null;
    actionMessage = null;
    notifyListeners();

    try {
      final result = await _repository.fetchUsers(
        status: activeStatus,
        search: searchQuery,
      );
      counts = result.counts;
      users = result.users;
      currentPage = 1;
    } catch (e) {
      errorMessage = e.toString();
      users = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setSearch(String value) {
    searchQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      load(search: searchQuery);
    });
    notifyListeners();
  }

  void setPage(int page) {
    currentPage = page.clamp(1, totalPages);
    notifyListeners();
  }

  Future<String?> approve(int userId) async {
    try {
      actionMessage = await _repository.approveUser(userId);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> reject(int userId, {String? comments}) async {
    try {
      actionMessage = await _repository.rejectUser(userId, comments: comments);
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

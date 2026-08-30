import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/clients_repository.dart';
import '../models/client_model.dart';

class ClientsProvider extends ChangeNotifier {
  ClientsProvider(this._repository);

  final ClientsRepository _repository;

  static const pageSize = 6;

  String searchQuery = '';
  List<ClientListItem> _allClients = [];
  int currentPage = 1;
  bool isLoading = false;
  String? errorMessage;
  Timer? _searchDebounce;

  List<ClientListItem> get filteredClients => _allClients;

  int get totalPages {
    final count = filteredClients.length;
    if (count == 0) return 1;
    return (count / pageSize).ceil();
  }

  List<ClientListItem> get pagedClients {
    final items = filteredClients;
    if (items.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    if (start >= items.length) return const [];
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  Future<void> load({String? search}) async {
    if (search != null) searchQuery = search;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _allClients = await _repository.fetchClients(search: searchQuery);
      currentPage = 1;
    } catch (e) {
      errorMessage = e.toString();
      _allClients = [];
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

  Future<String?> updateClient({
    required ClientListItem client,
    required ClientProfileUpdate profile,
    required bool isActive,
  }) async {
    try {
      await _repository.updateClientProfile(
        userId: client.userId,
        profile: profile,
      );

      if (isActive != client.isActive) {
        await _repository.setClientActive(
          userId: client.userId,
          isActive: isActive,
        );
      }

      _allClients = _allClients
          .map(
            (item) => item.userId == client.userId
                ? item.copyWith(
                    name: profile.name,
                    mobileNumber: profile.mobileNumber,
                    email: profile.email,
                    address: profile.address,
                    businessName: profile.businessName,
                    contactPersonName: profile.contactPersonName,
                    gstNumber: profile.gstNumber,
                    isActive: isActive,
                    profileCompleted: profile.profileCompleted,
                  )
                : item,
          )
          .toList();
      notifyListeners();
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

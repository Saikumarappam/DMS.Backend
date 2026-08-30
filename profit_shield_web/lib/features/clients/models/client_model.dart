class ClientProfileUpdate {
  const ClientProfileUpdate({
    required this.name,
    required this.mobileNumber,
    required this.email,
    this.address = '',
    this.businessName = '',
    this.contactPersonName = '',
    this.gstNumber = '',
    this.profileCompleted = true,
  });

  final String name;
  final String mobileNumber;
  final String email;
  final String address;
  final String businessName;
  final String contactPersonName;
  final String gstNumber;
  final bool profileCompleted;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobileNumber': mobileNumber,
        'email': email,
        'address': address,
        'businessName': businessName,
        'contactPersonName': contactPersonName,
        'gstNumber': gstNumber,
        'profileCompleted': profileCompleted,
      };
}

class ClientListItem {
  const ClientListItem({
    required this.userId,
    required this.name,
    required this.clientName,
    required this.mobileNumber,
    required this.isActive,
    required this.pendingTasks,
    this.gstNumber,
    this.email = '',
    this.address = '',
    this.businessName = '',
    this.contactPersonName = '',
    this.panNumber = '',
    this.roleName = 'Client',
    this.profileCompleted = false,
  });

  final int userId;
  final String name;
  final String clientName;
  final String? gstNumber;
  final String mobileNumber;
  final bool isActive;
  final int pendingTasks;
  final String email;
  final String address;
  final String businessName;
  final String contactPersonName;
  final String panNumber;
  final String roleName;
  final bool profileCompleted;

  String get gstinDisplay {
    final value = gstNumber?.trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return '—';
    }
    return value;
  }

  factory ClientListItem.fromJson(Map<String, dynamic> json) {
    final businessName = '${json['BusinessName'] ?? json['businessName'] ?? ''}'.trim();
    final name = '${json['Name'] ?? json['name'] ?? ''}'.trim();
    final displayName = businessName.isNotEmpty ? businessName : name;

    return ClientListItem(
      userId: _asInt(json['UserId'] ?? json['userId']),
      name: name,
      clientName: displayName.isNotEmpty ? displayName : '—',
      gstNumber: json['GSTNumber']?.toString() ?? json['gstNumber']?.toString(),
      mobileNumber: '${json['MobileNumber'] ?? json['mobileNumber'] ?? ''}',
      isActive: json['IsActive'] != false && json['isActive'] != false,
      pendingTasks: _asInt(
        json['PendingTasks'] ??
            json['pendingTasks'] ??
            json['PendingDocuments'] ??
            json['pendingDocuments'],
      ),
      email: '${json['Email'] ?? json['email'] ?? ''}',
      address: '${json['Address'] ?? json['address'] ?? ''}',
      businessName: businessName,
      contactPersonName: '${json['ContactPersonName'] ?? json['contactPersonName'] ?? ''}',
      panNumber: '${json['PANNumber'] ?? json['panNumber'] ?? ''}',
      roleName: '${json['RoleName'] ?? json['roleName'] ?? 'Client'}',
      profileCompleted: json['ProfileCompleted'] == true || json['profileCompleted'] == true,
    );
  }

  ClientListItem copyWith({
    String? name,
    String? mobileNumber,
    String? email,
    String? address,
    String? businessName,
    String? contactPersonName,
    String? gstNumber,
    bool? isActive,
    bool? profileCompleted,
  }) {
    final nextBusinessName = businessName ?? this.businessName;
    final nextName = name ?? this.name;
    final displayName =
        nextBusinessName.isNotEmpty ? nextBusinessName : (nextName.isNotEmpty ? nextName : clientName);

    return ClientListItem(
      userId: userId,
      name: nextName,
      clientName: displayName,
      gstNumber: gstNumber ?? this.gstNumber,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isActive: isActive ?? this.isActive,
      pendingTasks: pendingTasks,
      email: email ?? this.email,
      address: address ?? this.address,
      businessName: nextBusinessName,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      panNumber: panNumber,
      roleName: roleName,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

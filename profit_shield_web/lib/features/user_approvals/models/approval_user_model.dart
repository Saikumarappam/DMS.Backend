enum UserApprovalStatus { pending, approved, rejected }

UserApprovalStatus userApprovalStatusFromApi(String value) {
  switch (value.toLowerCase()) {
    case 'approved':
      return UserApprovalStatus.approved;
    case 'rejected':
      return UserApprovalStatus.rejected;
    default:
      return UserApprovalStatus.pending;
  }
}

String userApprovalStatusToApi(UserApprovalStatus status) {
  switch (status) {
    case UserApprovalStatus.approved:
      return 'Approved';
    case UserApprovalStatus.rejected:
      return 'Rejected';
    case UserApprovalStatus.pending:
      return 'Pending';
  }
}

class UserApprovalCounts {
  const UserApprovalCounts({
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int pending;
  final int approved;
  final int rejected;

  factory UserApprovalCounts.empty() => const UserApprovalCounts(
        pending: 0,
        approved: 0,
        rejected: 0,
      );

  factory UserApprovalCounts.fromJson(Map<String, dynamic> json) {
    return UserApprovalCounts(
      pending: _asInt(json['PendingCount'] ?? json['pendingCount']),
      approved: _asInt(json['ApprovedCount'] ?? json['approvedCount']),
      rejected: _asInt(json['RejectedCount'] ?? json['rejectedCount']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

class ApprovalUser {
  ApprovalUser({
    required this.userId,
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.panNumber,
    required this.businessName,
    required this.contactPersonName,
    required this.username,
    required this.userStatus,
    required this.createdDate,
    this.modifiedDate,
    this.gstNumber,
    this.pendingDocuments = 0,
    this.profileCompleted = false,
    this.isActive = true,
    this.roleName = 'Client',
  });

  final int userId;
  final String name;
  final String mobileNumber;
  final String email;
  final String panNumber;
  final String businessName;
  final String contactPersonName;
  final String? gstNumber;
  final String username;
  final String userStatus;
  final bool profileCompleted;
  final bool isActive;
  final String roleName;
  final DateTime? createdDate;
  final DateTime? modifiedDate;
  final int pendingDocuments;

  UserApprovalStatus get status => userApprovalStatusFromApi(userStatus);

  factory ApprovalUser.fromJson(Map<String, dynamic> json) {
    return ApprovalUser(
      userId: _asInt(json['UserId'] ?? json['userId']),
      name: '${json['Name'] ?? json['name'] ?? ''}',
      mobileNumber: '${json['MobileNumber'] ?? json['mobileNumber'] ?? ''}',
      email: '${json['Email'] ?? json['email'] ?? ''}',
      panNumber: '${json['PANNumber'] ?? json['panNumber'] ?? ''}',
      businessName: '${json['BusinessName'] ?? json['businessName'] ?? ''}',
      contactPersonName: '${json['ContactPersonName'] ?? json['contactPersonName'] ?? ''}',
      gstNumber: json['GSTNumber']?.toString() ?? json['gstNumber']?.toString(),
      username: '${json['Username'] ?? json['username'] ?? ''}',
      userStatus: '${json['UserStatus'] ?? json['userStatus'] ?? 'Pending'}',
      profileCompleted: json['ProfileCompleted'] == true || json['profileCompleted'] == true,
      isActive: json['IsActive'] != false && json['isActive'] != false,
      roleName: '${json['RoleName'] ?? json['roleName'] ?? 'Client'}',
      createdDate: _parseDate(json['CreatedDate'] ?? json['createdDate']),
      modifiedDate: _parseDate(json['ModifiedDate'] ?? json['modifiedDate']),
      pendingDocuments: _asInt(json['PendingDocuments'] ?? json['pendingDocuments']),
    );
  }

  ApprovalUser copyWith({
    String? name,
    String? businessName,
    String? mobileNumber,
  }) {
    return ApprovalUser(
      userId: userId,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email,
      panNumber: panNumber,
      businessName: businessName ?? this.businessName,
      contactPersonName: contactPersonName,
      gstNumber: gstNumber,
      username: username,
      userStatus: userStatus,
      profileCompleted: profileCompleted,
      isActive: isActive,
      roleName: roleName,
      createdDate: createdDate,
      modifiedDate: modifiedDate,
      pendingDocuments: pendingDocuments,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}

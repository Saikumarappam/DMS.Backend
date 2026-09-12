import '../../core/utils/json_utils.dart';

class UserModel {
  const UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.roleName,
    required this.userStatus,
    required this.profileCompleted,
    this.businessName,
    this.panNumber,
    this.address,
    this.contactPersonName,
    this.gstNumber,
    this.username,
    this.isActive = true,
    this.createdDate,
  });

  final int userId;
  final String name;
  final String email;
  final String mobileNumber;
  final String roleName;
  final String userStatus;
  final bool profileCompleted;
  final String? businessName;
  final String? panNumber;
  final String? address;
  final String? contactPersonName;
  final String? gstNumber;
  final String? username;
  final bool isActive;
  final DateTime? createdDate;

  bool get isSuperAdmin => roleName == 'SuperAdmin';
  bool get isClient => roleName == 'Client';

  /// PAN is the client User ID; falls back to username or numeric id.
  String get userLoginId {
    if (panNumber != null && panNumber!.trim().isNotEmpty) {
      return panNumber!.trim().toUpperCase();
    }
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }
    return userId.toString();
  }

  UserModel copyWith({
    int? userId,
    String? name,
    String? email,
    String? mobileNumber,
    String? roleName,
    String? userStatus,
    bool? profileCompleted,
    String? businessName,
    String? panNumber,
    String? address,
    String? contactPersonName,
    String? gstNumber,
    String? username,
    bool? isActive,
    DateTime? createdDate,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      roleName: roleName ?? this.roleName,
      userStatus: userStatus ?? this.userStatus,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      businessName: businessName ?? this.businessName,
      panNumber: panNumber ?? this.panNumber,
      address: address ?? this.address,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      gstNumber: gstNumber ?? this.gstNumber,
      username: username ?? this.username,
      isActive: isActive ?? this.isActive,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: (JsonUtils.pick(json, 'userId') as num).toInt(),
      name: JsonUtils.pick(json, 'name') as String? ?? '',
      email: JsonUtils.pick(json, 'email') as String? ?? '',
      mobileNumber: JsonUtils.pick(json, 'mobileNumber') as String? ?? '',
      roleName: JsonUtils.pick(json, 'roleName') as String? ?? '',
      userStatus: JsonUtils.pick(json, 'userStatus') as String? ?? '',
      profileCompleted: JsonUtils.pick(json, 'profileCompleted') as bool? ?? false,
      businessName: JsonUtils.pick(json, 'businessName') as String?,
      panNumber: JsonUtils.pick(json, 'panNumber') as String?,
      address: JsonUtils.pick(json, 'address') as String?,
      contactPersonName: JsonUtils.pick(json, 'contactPersonName') as String?,
      gstNumber: JsonUtils.pick(json, 'gstNumber') as String?,
      username: JsonUtils.pick(json, 'username') as String?,
      isActive: JsonUtils.pick(json, 'isActive') as bool? ?? true,
      createdDate: JsonUtils.pick(json, 'createdDate') != null
          ? DateTime.tryParse('${JsonUtils.pick(json, 'createdDate')}')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'mobileNumber': mobileNumber,
        'roleName': roleName,
        'userStatus': userStatus,
        'profileCompleted': profileCompleted,
        'businessName': businessName,
        'panNumber': panNumber,
        'address': address,
        'contactPersonName': contactPersonName,
        'gstNumber': gstNumber,
        'username': username,
        'isActive': isActive,
        if (createdDate != null) 'createdDate': createdDate!.toIso8601String(),
      };
}

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.name,
    required this.mobileNumber,
    required this.email,
    this.address,
    this.businessName,
    this.contactPersonName,
    this.gstNumber,
    this.profileCompleted = true,
  });

  final String name;
  final String mobileNumber;
  final String email;
  final String? address;
  final String? businessName;
  final String? contactPersonName;
  final String? gstNumber;
  final bool profileCompleted;

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobileNumber': mobileNumber,
        'email': email,
        if (address != null) 'address': address,
        if (businessName != null) 'businessName': businessName,
        if (contactPersonName != null) 'contactPersonName': contactPersonName,
        if (gstNumber != null) 'gstNumber': gstNumber,
        'profileCompleted': profileCompleted,
      };
}

class UserApprovalRequest {
  const UserApprovalRequest({
    required this.action,
    this.username,
    this.password,
    this.comments,
  });

  final String action;
  final String? username;
  final String? password;
  final String? comments;

  Map<String, dynamic> toJson() => {
        'action': action,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
        if (comments != null) 'comments': comments,
      };
}

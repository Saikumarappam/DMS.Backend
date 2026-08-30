class AppUser {
  AppUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.roleName,
    required this.userStatus,
    this.businessName,
    this.profileCompleted = false,
  });

  final int userId;
  final String name;
  final String email;
  final String mobileNumber;
  final String roleName;
  final String userStatus;
  final String? businessName;
  final bool profileCompleted;

  bool get isSuperAdmin => roleName.toLowerCase() == 'superadmin';
  bool get isClient => roleName.toLowerCase() == 'client';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: _asInt(json['UserId'] ?? json['userId']),
      name: '${json['Name'] ?? json['name'] ?? ''}',
      email: '${json['Email'] ?? json['email'] ?? ''}',
      mobileNumber: '${json['MobileNumber'] ?? json['mobileNumber'] ?? ''}',
      businessName: json['BusinessName']?.toString() ?? json['businessName']?.toString(),
      roleName: '${json['RoleName'] ?? json['roleName'] ?? ''}',
      userStatus: '${json['UserStatus'] ?? json['userStatus'] ?? ''}',
      profileCompleted: json['ProfileCompleted'] == true || json['profileCompleted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'UserId': userId,
        'Name': name,
        'Email': email,
        'MobileNumber': mobileNumber,
        'BusinessName': businessName,
        'RoleName': roleName,
        'UserStatus': userStatus,
        'ProfileCompleted': profileCompleted,
      };

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }
}

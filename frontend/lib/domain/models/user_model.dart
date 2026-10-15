class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    this.employeeCode,
    this.designation,
  });

  final String id;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final String? employeeCode;
  final String? designation;

  String get fullName => '$firstName $lastName';
  bool get isHr => role == 'HR_ADMIN' || role == 'SUPER_ADMIN';
  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isEmployee => role == 'EMPLOYEE';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      employeeCode: json['employeeCode'] as String?,
      designation: json['designation'] as String?,
    );
  }
}

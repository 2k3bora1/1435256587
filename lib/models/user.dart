class User {
  final String username;
  final String passwordHash;
  final String companyName;
  final String aadhaar;
  final String phone;

  User({
    required this.username,
    required this.passwordHash,
    required this.companyName,
    required this.aadhaar,
    required this.phone,
  });

  // Convert User object to a Map
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password_hash': passwordHash,
      'company_name': companyName,
      'aadhaar': aadhaar,
      'phone': phone,
    };
  }

  // Create User object from a Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      username: map['username'],
      passwordHash: map['password_hash'],
      companyName: map['company_name'],
      aadhaar: map['aadhaar'],
      phone: map['phone'],
    );
  }

  // Create a copy of User with modified fields
  User copyWith({
    String? username,
    String? passwordHash,
    String? companyName,
    String? aadhaar,
    String? phone,
  }) {
    return User(
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      companyName: companyName ?? this.companyName,
      aadhaar: aadhaar ?? this.aadhaar,
      phone: phone ?? this.phone,
    );
  }
}
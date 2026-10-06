enum UserRole { admin, petugas }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'petugas':
      return UserRole.petugas;
    default:
      throw ArgumentError('Role tidak dikenal: $value');
  }
}

class AuthSession {
  final String token;
  final UserRole role;
  final String nama;

  AuthSession({required this.token, required this.role, required this.nama});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      role: userRoleFromString(json['role'] as String),
      nama: json['nama'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'role': role == UserRole.admin ? 'admin' : 'petugas',
    'nama': nama,
  };
}

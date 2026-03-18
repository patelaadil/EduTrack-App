class UserProfile {
  final String id;
  final String role; // 'admin' | 'teacher' | 'student'
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.role,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    required this.isActive,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id:       map['id']        as String,
    role:     map['role']      as String,
    name:     map['name']      as String,
    email:    map['email']     as String?,
    phone:    map['phone']     as String?,
    photoUrl: map['photo_url'] as String?,
    isActive: map['is_active'] as bool? ?? true,
  );

  bool get isTeacher => role == 'teacher';
  bool get isStudent  => role == 'student';
  bool get isAdmin    => role == 'admin';
}

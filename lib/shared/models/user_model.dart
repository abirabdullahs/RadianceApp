/// Matches `users` table (see `plan/03_database_roadmap.md`).
enum UserRole {
  admin,
  student,
  teacher;

  static UserRole fromJson(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.student,
    );
  }

  String toJson() => name;
}

/// `class_level` CHECK constraint values.
enum ClassLevel {
  ssc('SSC'),
  hsc('HSC'),
  admission('Admission'),
  other('Other');

  const ClassLevel(this.dbValue);

  final String dbValue;

  static ClassLevel? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final e in ClassLevel.values) {
      if (e.dbValue == value) return e;
    }
    return null;
  }

  String toJson() => dbValue;
}

class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    required this.fullNameBn,
    this.email,
    this.fullNameEn,
    this.avatarUrl,
    required this.role,
    this.studentId,
    this.dateOfBirth,
    this.guardianPhone,
    this.address,
    this.college,
    this.classLevel,
    this.fcmToken,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String phone;
  final String? email;
  final String fullNameBn;
  final String? fullNameEn;
  final String? avatarUrl;
  final UserRole role;
  final String? studentId;
  final DateTime? dateOfBirth;
  final String? guardianPhone;
  final String? address;
  final String? college;
  final ClassLevel? classLevel;
  final String? fcmToken;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      fullNameBn: json['full_name_bn'] as String,
      fullNameEn: json['full_name_en'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromJson(json['role'] as String? ?? 'student'),
      studentId: json['student_id'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      guardianPhone: json['guardian_phone'] as String?,
      address: json['address'] as String?,
      college: json['college'] as String?,
      classLevel: ClassLevel.fromJson(json['class_level'] as String?),
      fcmToken: json['fcm_token'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'phone': phone,
      'email': email,
      'full_name_bn': fullNameBn,
      'full_name_en': fullNameEn,
      'avatar_url': avatarUrl,
      'role': role.toJson(),
      'student_id': studentId,
      'date_of_birth': dateOfBirth == null
          ? null
          : '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
              '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
              '${dateOfBirth!.day.toString().padLeft(2, '0')}',
      'guardian_phone': guardianPhone,
      'address': address,
      'college': college,
      'class_level': classLevel?.toJson(),
      'fcm_token': fcmToken,
      'is_active': isActive,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? email,
    String? fullNameBn,
    String? fullNameEn,
    String? avatarUrl,
    UserRole? role,
    String? studentId,
    DateTime? dateOfBirth,
    String? guardianPhone,
    String? address,
    String? college,
    ClassLevel? classLevel,
    String? fcmToken,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fullNameBn: fullNameBn ?? this.fullNameBn,
      fullNameEn: fullNameEn ?? this.fullNameEn,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      address: address ?? this.address,
      college: college ?? this.college,
      classLevel: classLevel ?? this.classLevel,
      fcmToken: fcmToken ?? this.fcmToken,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _parseDate(dynamic value) {
  final dt = _parseDateTime(value);
  if (dt == null) return null;
  return DateTime.utc(dt.year, dt.month, dt.day);
}

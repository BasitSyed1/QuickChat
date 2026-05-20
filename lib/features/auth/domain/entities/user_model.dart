class UserModel {
  final String? id;
  final String? name;
  final String? email;
  final String? password;
  final String? bio;
  final DateTime? lastSeen;

  const UserModel({
    this.id,
    this.name,
    this.email,
    this.password,
    this.bio,
    this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw = json['last_seen'] as String?;
    return UserModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      lastSeen: lastSeenRaw == null ? null : DateTime.tryParse(lastSeenRaw),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'bio': bio,
        if (lastSeen != null) 'last_seen': lastSeen!.toUtc().toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? bio,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      bio: bio ?? this.bio,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

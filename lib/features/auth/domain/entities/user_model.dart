class UserModel {
  final String? id;
  final String? name;
  final String? email;
  final String? password;
  final String? bio;

  const UserModel({
    this.id,
    this.name,
    this.email,
    this.password,
    this.bio,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      password: json['password'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'bio': bio,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? bio,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      bio: bio ?? this.bio,
    );
  }
}

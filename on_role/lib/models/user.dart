class User {
  String id;
  String name;
  String email;
  String password;
  String? avatarUrl;
  String? bio;
  DateTime birthDate;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.avatarUrl,
    this.bio,
    required this.birthDate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      password: json['password'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'],
      birthDate: DateTime.parse(json['birthDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'birthDate': birthDate.toIso8601String(),
    };
  }
}
/// Perfil público. E-mail e senha ficam só na camada de autenticação.
class User {
  String id;
  String name;
  String? avatarUrl;
  String? bio;

  /// Só vem preenchida para o próprio usuário (fica num documento privado).
  DateTime? birthDate;

  /// Check-ins por local (id do local → quantidade): base do match geossocial.
  Map<String, int> visits;

  User({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.birthDate,
    Map<String, int>? visits,
  }) : visits = visits ?? {};

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'],
      birthDate: json['birthDate'] == null ? null : DateTime.parse(json['birthDate']),
      visits: (json['visits'] as Map<String, dynamic>?)?.map((venueId, count) => MapEntry(venueId, count as int)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'birthDate': birthDate?.toIso8601String(),
      'visits': visits,
    };
  }
}

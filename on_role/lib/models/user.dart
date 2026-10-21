import 'media.dart';

/// Perfil público. E-mail e senha ficam só na camada de autenticação.
class User {
  String id;
  String name;
  String? avatarUrl;
  String? bio;

  /// Foto de perfil (guardada no banco como as mídias dos posts).
  MediaRef? photo;

  /// "Gostos de rolê" declarados (ver interest_catalog.dart): parte da
  /// afinidade do match geossocial.
  List<String> interests;

  /// Só vem preenchida para o próprio usuário (fica num documento privado).
  DateTime? birthDate;

  /// Check-ins por local (id do local → quantidade): base do match geossocial.
  Map<String, int> visits;

  User({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.photo,
    List<String>? interests,
    this.birthDate,
    Map<String, int>? visits,
  }) : interests = interests ?? [],
       visits = visits ?? {};

  /// "@anasouza", mostrado abaixo do nome.
  String get handle => '@${name.toLowerCase().replaceAll(' ', '')}';

  /// Total de check-ins, somando todos os locais.
  int get totalVisits => visits.values.fold(0, (sum, count) => sum + count);

  factory User.fromJson(Map<String, dynamic> json) {
    final photo = json['photo'] as Map?;
    return User(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'],
      photo: photo == null
          ? null
          : MediaRef.fromJson(Map<String, dynamic>.from(photo)),
      interests: List<String>.from(json['interests'] as List? ?? const []),
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate']),
      visits: (json['visits'] as Map<String, dynamic>?)?.map(
        (venueId, count) => MapEntry(venueId, count as int),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'photo': photo?.toJson(),
      'interests': interests,
      'birthDate': birthDate?.toIso8601String(),
      'visits': visits,
    };
  }
}

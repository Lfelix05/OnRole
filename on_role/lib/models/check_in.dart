/// Presença validada por geocerca. Guarda só o local e os horários, nunca as
/// coordenadas do usuário (mitigação de privacidade da seção 6 do projeto).
class CheckIn {
  final String id;
  final String userId;
  final String venueId;
  final DateTime checkedInAt;
  DateTime? checkedOutAt;

  CheckIn({
    required this.id,
    required this.userId,
    required this.venueId,
    required this.checkedInAt,
    this.checkedOutAt,
  });

  bool get isActive => checkedOutAt == null;

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'],
      userId: json['userId'],
      venueId: json['venueId'],
      checkedInAt: DateTime.parse(json['checkedInAt']),
      checkedOutAt: json['checkedOutAt'] == null ? null : DateTime.parse(json['checkedOutAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'venueId': venueId,
      'checkedInAt': checkedInAt.toIso8601String(),
      'checkedOutAt': checkedOutAt?.toIso8601String(),
    };
  }
}

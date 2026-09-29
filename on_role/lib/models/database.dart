import 'package:latlong2/latlong.dart';

import 'check_in.dart';
import 'posts.dart';
import 'user.dart';
import 'venue.dart';

class MockDatabase {
  MockDatabase._internal() {
    _seed();
    _seedVenues();
  }

  static final MockDatabase instance = MockDatabase._internal();

  final List<User> _users = [];
  final List<Posts> _posts = [];
  final List<Venue> _venues = [];
  final List<CheckIn> _checkIns = [];
  final Map<String, int> _crowdBaseline = {};

  List<User> get users => List.unmodifiable(_users);
  List<Posts> get posts => List.unmodifiable(_posts);
  List<Venue> get venues => List.unmodifiable(_venues);
  List<CheckIn> get checkIns => List.unmodifiable(_checkIns);

  /// Lotação média de cada local, usada pelo simulador de movimento.
  Map<String, int> get crowdBaseline => Map.unmodifiable(_crowdBaseline);

  Venue? findVenueById(String id) {
    for (final venue in _venues) {
      if (venue.id == id) return venue;
    }
    return null;
  }

  int activeCheckInsAt(String venueId) {
    return _checkIns.where((checkIn) => checkIn.venueId == venueId && checkIn.isActive).length;
  }

  void addCheckIn(CheckIn checkIn) {
    _checkIns.add(checkIn);
  }

  User? findUserByEmail(String email) {
    for (final user in _users) {
      if (user.email == email) return user;
    }
    return null;
  }

  User? findUserById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  bool emailExists(String email) => findUserByEmail(email) != null;

  void addUser(User user) {
    _users.add(user);
  }

  void addPost(Posts post) {
    _posts.insert(0, post);
  }

  void _seed() {
    final demoUser = User(
      id: 'demo-user',
      name: 'Convidado Demo',
      email: 'demo@onrole.com',
      password: '123456',
      birthDate: DateTime(2000, 1, 1),
      bio: 'Conta de demonstração do OnRolê.',
    );
    _users.add(demoUser);

    final now = DateTime.now();
    _posts.addAll([
      Posts(
        id: 'seed-1',
        title: 'Sextou no centro!',
        content: 'Bar lotado e som bom, bora pra cá.',
        type: PostType.text,
        authorId: demoUser.id,
        venueId: 'boteco-central',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Posts(
        id: 'seed-2',
        title: 'Pico na praça',
        content: 'Movimento começando a subir por aqui.',
        type: PostType.text,
        authorId: demoUser.id,
        venueId: 'praca-municipal',
        createdAt: now.subtract(const Duration(minutes: 40)),
        updatedAt: now.subtract(const Duration(minutes: 40)),
      ),
    ]);
  }

  /// Locais de demonstração no centro de Colatina - ES. As praças e a área de
  /// eventos são espaços públicos com coordenadas tiradas do OpenStreetMap;
  /// os bares são fictícios. Troque-os pelos 5 estabelecimentos parceiros
  /// do experimento, medindo as coordenadas no próprio local.
  void _seedVenues() {
    void add(String id, String name, VenueCategory category, double lat, double lng,
        {required double radius, required int crowd}) {
      _venues.add(Venue(
        id: id,
        name: name,
        category: category,
        location: LatLng(lat, lng),
        radiusMeters: radius,
      ));
      _crowdBaseline[id] = crowd;
    }

    add('praca-municipal', 'Praça Municipal', VenueCategory.praca, -19.53477, -40.62870, radius: 80, crowd: 35);
    add('praca-sol-poente', 'Praça do Sol Poente', VenueCategory.praca, -19.53693, -40.63380, radius: 70, crowd: 18);
    add('parque-beira-rio', 'Parque Beira-Rio', VenueCategory.praca, -19.52543, -40.61934, radius: 100, crowd: 25);
    add('area-eventos', 'Área de Eventos', VenueCategory.evento, -19.53612, -40.63612, radius: 150, crowd: 60);
    add('boteco-central', 'Boteco Central', VenueCategory.bar, -19.53368, -40.62655, radius: 50, crowd: 42);
    add('lounge-beira-rio', 'Lounge Beira-Rio', VenueCategory.balada, -19.52626, -40.61800, radius: 60, crowd: 55);
    add('esquina-do-chopp', 'Esquina do Chopp', VenueCategory.bar, -19.53870, -40.63433, radius: 50, crowd: 22);
  }
}

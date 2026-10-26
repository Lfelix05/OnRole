import 'dart:math' as math;

import '../data/interest_catalog.dart';
import '../data/venue_catalog.dart';
import '../models/posts.dart';
import '../models/user.dart';

/// "Jeito de sair" de uma pessoa sintética: os locais aonde tende a ir (com
/// peso) e os gostos de rolê que tende a marcar.
typedef _Taste = ({Map<String, int> venues, List<String> interests, List<String> bios});

const _tastes = <_Taste>[
  (
    venues: {'bakhanas': 3, 'espetinho-do-denis': 3, 'bar-ladym': 2, 'cervejaria-divina-beer': 2},
    interests: ['Bar', 'Samba e pagode', 'Gastronomia', 'Sertanejo'],
    bios: ['Um chopp e uma boa conversa.', 'Pagode no fim de semana é sagrado.'],
  ),
  (
    venues: {'caza-up': 3, 'dj-pub': 3, 'bunker-music-house': 2},
    interests: ['Balada', 'Eletrônica', 'Funk', 'Rap e trap'],
    bios: ['Só volto quando o sol nascer.', 'Pista cheia, playlist boa.'],
  ),
  (
    venues: {'area-verde': 3, 'caraiva-beach-bar': 3, 'bharem': 2},
    interests: ['Praça e ar livre', 'Forró', 'MPB', 'Esporte'],
    bios: ['Fim de tarde ao ar livre.', 'Forró no sábado, praça no domingo.'],
  ),
  (
    venues: {'bunker-music-house': 3, 'cerimonial-zoca': 2, 'cervejaria-divina-beer': 2},
    interests: ['Show ao vivo', 'Rock', 'MPB', 'Sertanejo'],
    bios: ['Música ao vivo sempre.', 'Atrás de um show bom pra ir.'],
  ),
];

const _firstNames = [
  'Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Felipe', 'Gabriela', 'Heitor', 'Isabela', 'João',
  'Karina', 'Leonardo', 'Mariana', 'Nicolas', 'Olívia', 'Paulo', 'Renata', 'Samuel', 'Tainá', 'Vinícius',
  'Yasmin', 'André', 'Bianca', 'Caio', 'Débora', 'Eduardo', 'Fernanda', 'Gustavo', 'Helena', 'Igor',
];

const _lastNames = [
  'Almeida', 'Barbosa', 'Cardoso', 'Dias', 'Esteves', 'Ferraz', 'Gomes', 'Honorato', 'Lacerda', 'Moura',
  'Nogueira', 'Pacheco', 'Queiroz', 'Ramos', 'Siqueira', 'Teixeira', 'Valente', 'Xavier',
];

/// Pessoas fictícias da versão de demonstração, geradas com semente fixa:
/// nomes sorteados de listas, gostos e histórico de visitas tirados de um
/// "jeito de sair" principal (75% das visitas) e de um secundário. São elas
/// que aparecem nas Conexões, no feed e na busca. Nenhum dado de pessoa real.
class SyntheticPopulation {
  SyntheticPopulation({int seed = 1}) : _random = math.Random(seed);

  final math.Random _random;

  List<User> people(int count) {
    final names = <String>{};
    final people = <User>[];
    for (var i = 0; i < count; i++) {
      String name;
      do {
        name = '${_pick(_firstNames)} ${_pick(_lastNames)}';
      } while (!names.add(name));

      final main = _pick(_tastes);
      final second = _pick(_tastes.where((taste) => taste != main).toList());
      final interests = <String>{
        ..._sample(main.interests, 2 + _random.nextInt(2)),
        ..._sample(second.interests, _random.nextInt(3)),
      }.take(maxInterests).toList();

      final visits = <String, int>{};
      final count = 3 + _random.nextInt(20);
      for (var v = 0; v < count; v++) {
        final venueId = _weighted(_random.nextDouble() < 0.75 ? main.venues : second.venues);
        visits.update(venueId, (n) => n + 1, ifAbsent: () => 1);
      }

      people.add(User(
        id: 'sintetico-${(i + 1).toString().padLeft(2, '0')}',
        name: name,
        bio: _random.nextBool() ? _pick(main.bios) : null,
        interests: interests,
        visits: visits,
      ));
    }
    return people;
  }

  /// Posts para o feed não abrir vazio: convites para sair, sem opinião nem
  /// avaliação sobre os locais (que são estabelecimentos reais).
  List<Posts> posts(List<User> authors, {required DateTime now, int count = 12}) {
    const templates = <({String text, bool withVenue, bool atVenue})>[
      (text: 'Alguém topa {local} hoje? Chego lá pelas 22h.', withVenue: true, atVenue: false),
      (text: 'Quem vai no {local} mais tarde?', withVenue: true, atVenue: false),
      (text: 'Tô no {local} com a galera, chega mais!', withVenue: true, atVenue: true),
      (text: 'Bora marcar um rolê no sábado? Tô sem ideia de lugar.', withVenue: false, atVenue: false),
      (text: 'Sextou! Quem tá na rua hoje?', withVenue: false, atVenue: false),
      (text: 'Procurando gente pra ir num show essa semana.', withVenue: false, atVenue: false),
      (text: 'Alguém sabe se vai ter música ao vivo hoje?', withVenue: false, atVenue: false),
      (text: 'Primeira vez saindo em Colatina, onde a galera costuma ir?', withVenue: false, atVenue: false),
    ];
    final posts = <Posts>[];
    for (var i = 0; i < count; i++) {
      final author = _pick(authors);
      final template = _pick(templates);
      final venueId = template.withVenue && author.visits.isNotEmpty ? _weighted(author.visits) : null;
      posts.add(Posts(
        id: 'sintetico-post-$i',
        authorId: author.id,
        authorName: author.name,
        text: template.text.replaceAll('{local}', venueId == null ? 'algum lugar' : findVenue(venueId)!.name),
        venueId: venueId,
        atVenue: template.atVenue && venueId != null,
        likedBy: [for (final fan in _sample(authors, _random.nextInt(6))) if (fan != author) fan.id],
        createdAt: now.subtract(Duration(minutes: 5 + i * 20 + _random.nextInt(15))),
      ));
    }
    return posts;
  }

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  List<T> _sample<T>(List<T> items, int count) => (List.of(items)..shuffle(_random)).take(count).toList();

  String _weighted(Map<String, int> weights) {
    var target = _random.nextInt(weights.values.fold(0, (sum, weight) => sum + weight));
    for (final entry in weights.entries) {
      target -= entry.value;
      if (target < 0) return entry.key;
    }
    return weights.keys.last;
  }
}

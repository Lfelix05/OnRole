// Perfis de demonstração do OnRolê: pessoas fictícias, com avatar ilustrado,
// gostos de rolê, bio, visitas por local (base da afinidade nas Conexões) e
// alguns posts. Os posts são convites e assuntos do dia a dia: nenhum elogia
// nem afirma nada sobre os estabelecimentos reais do catálogo.
//
// Os gostos seguem a ordem de lib/data/interest_catalog.dart, e os locais
// usam os ids de lib/data/venue_catalog.dart.

export const profiles = [
  {
    slug: 'marina',
    name: 'Marina Alves',
    birthDate: '1999-03-14',
    bio: 'Roda de samba, cerveja gelada e gente boa. 💛',
    interests: ['Bar', 'Samba e pagode', 'MPB', 'Gastronomia'],
    visits: { bakhanas: 3, bharem: 2 },
    avatar: 'avatar_marina.jpg',
  },
  {
    slug: 'rodrigo',
    name: 'Rodrigo Nunes',
    birthDate: '1996-08-02',
    bio: 'Baterista nas horas vagas. Show de rock? Tô dentro.',
    interests: ['Bar', 'Show ao vivo', 'Rock'],
    visits: { 'bunker-music-house': 3, 'espetinho-do-denis': 1 },
    avatar: 'avatar_rodrigo.jpg',
  },
  {
    slug: 'camila',
    name: 'Camila Duarte',
    birthDate: '2002-11-21',
    bio: 'Se tem DJ, eu tô lá. 🎧',
    interests: ['Balada', 'Funk', 'Eletrônica'],
    visits: { 'dj-pub': 4, 'caza-up': 2 },
    avatar: 'avatar_camila.jpg',
  },
  {
    slug: 'beatriz',
    name: 'Beatriz Costa',
    birthDate: '2000-05-09',
    bio: 'Fim de tarde ao ar livre e forró no fim de semana. 🌻',
    interests: ['Praça e ar livre', 'Forró', 'MPB'],
    visits: { 'area-verde': 4, 'caraiva-beach-bar': 1 },
    avatar: 'avatar_beatriz.jpg',
  },
  {
    slug: 'gabriel',
    name: 'Gabriel Souza',
    birthDate: '1998-01-27',
    bio: 'Futebol de quinta, espetinho de sexta. ⚽',
    interests: ['Bar', 'Sertanejo', 'Esporte'],
    visits: { 'espetinho-do-denis': 4, 'bar-ladym': 2 },
    avatar: 'avatar_gabriel.jpg',
  },
  {
    slug: 'larissa',
    name: 'Larissa Mendes',
    birthDate: '1997-07-18',
    bio: 'Caçando a melhor cerveja artesanal e o melhor hambúrguer da cidade. 🍔🍺',
    interests: ['Bar', 'Show ao vivo', 'Gastronomia'],
    visits: { 'cervejaria-divina-beer': 3, bharem: 1 },
    avatar: 'avatar_larissa.jpg',
  },
];

// Na ordem em que entram no feed: o último aparece primeiro.
export const posts = [
  {
    author: 'gabriel',
    text: 'Churrasco de domingo com a família 🔥',
    photos: ['gabriel_espetinho.jpg'],
    likedBy: ['marina', 'larissa'],
  },
  {
    author: 'beatriz',
    text: 'Procurando gente pra aprender forró junto. Alguém?',
    likedBy: ['marina'],
    replies: [{ from: 'gabriel', text: 'Eu aprendo! Só não garanto não pisar no pé 😅' }],
  },
  {
    author: 'rodrigo',
    text: 'Ensaio da banda rendeu hoje 🤘',
    photos: ['rodrigo_bateria.jpg'],
    likedBy: ['camila', 'gabriel', 'larissa'],
  },
  {
    author: 'larissa',
    text: 'Aceito dicas de hambúrguer artesanal na cidade!',
    replies: [{ from: 'beatriz', text: 'Também quero saber!' }],
  },
  {
    author: 'camila',
    text: 'Começando a brincar de DJ em casa. Aceito sugestões de set!',
    photos: ['camila_vinil.jpg'],
    likedBy: ['rodrigo'],
  },
  {
    author: 'marina',
    text: 'Aprendendo umas músicas novas pro pagode de domingo 🎶',
    photos: ['marina_violao.jpg'],
    likedBy: ['beatriz', 'rodrigo'],
  },
  {
    author: 'gabriel',
    text: 'Quem joga uma pelada na quinta à noite? Falta gente pro time.',
    likedBy: ['rodrigo'],
  },
  {
    author: 'rodrigo',
    text: 'Bora montar um grupo pra ir nos shows de rock da região? Comenta aí.',
    replies: [{ from: 'gabriel', text: 'Tô dentro, me chama.' }],
  },
  {
    author: 'beatriz',
    text: 'Fim de tarde na beira do rio é outra coisa 🌅',
    photos: ['beatriz_rio.jpg'],
    likedBy: ['marina', 'camila', 'larissa', 'gabriel'],
  },
  {
    author: 'larissa',
    text: 'Hambúrguer e cerveja artesanal: o combo do fim de semana.',
    photos: ['larissa_hamburguer.jpg', 'larissa_chope.jpg'],
    likedBy: ['gabriel', 'marina'],
  },
  {
    author: 'camila',
    text: 'Tô montando um grupo pra dividir o Uber no sábado. Quem anima?',
    likedBy: ['larissa'],
    replies: [{ from: 'marina', text: 'Eu! Me põe no grupo.' }],
  },
  {
    author: 'marina',
    text: 'Alguém indica um lugar com samba ao vivo no fim de semana?',
    likedBy: ['gabriel'],
  },
  {
    author: 'beatriz',
    text: 'Alguém topa um piquenique na Área Verde no domingo?',
    venueId: 'area-verde',
    likedBy: ['larissa', 'camila'],
    replies: [{ from: 'marina', text: 'Topo! Levo o violão.' }],
  },
  {
    author: 'rodrigo',
    text: 'Saudade de show lotado. Quem mais?',
    photos: ['rodrigo_show.jpg'],
    likedBy: ['camila', 'larissa'],
  },
  {
    author: 'camila',
    text: 'Sextou! Quem vai sair hoje? 🎧',
    photos: ['camila_dj.jpg'],
    likedBy: ['rodrigo', 'marina', 'beatriz'],
  },
  {
    author: 'marina',
    text: 'Quinta-feira pede uma gelada com os amigos. Quem chega?',
    photos: ['marina_brinde.jpg'],
    likedBy: ['camila', 'gabriel', 'rodrigo'],
    replies: [{ from: 'camila', text: 'Eu chego! 🙋‍♀️' }],
  },
];

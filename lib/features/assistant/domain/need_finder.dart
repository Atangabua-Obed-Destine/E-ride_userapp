import 'dart:math' as math;

/// What a few typed words ask for: "pharmacie", "bus Douala demain", "chop",
/// "Romz", "phone". Plain Dart (no GetX), so it is tested on its own.
///
/// Instant and offline, in English, French and Pidgin; accents, capitals and a
/// one-letter slip do not matter. Address search carries on below the results.
class NeedFinder {
  final NeedContext context;
  NeedFinder(this.context) : _lexicon = _buildLexicon(context.extraWords);

  final List<_Lexeme> _lexicon;

  /// The best matches first, at most [limit].
  List<NeedHit> find(String text, {int limit = 3}) {
    final String q = normalize(text);
    if (q.length < 2) return const [];
    final List<String> tokens = q.split(' ');
    final Map<String, NeedHit> best = {};

    void add(NeedHit hit) {
      final String key = '${hit.type}:${hit.id ?? ''}:${hit.city ?? ''}:${hit.storeId ?? ''}';
      if ((best[key]?.score ?? -1) < hit.score) best[key] = hit;
    }

    // A bus destination, with "tomorrow" and friends.
    if (context.services.contains('bus')) {
      final int? day = _dayOffset(q);
      for (final BusPlace place in context.busPlaces) {
        final String city = normalize(place.city);
        final int s = _phraseScore(q, tokens, city, aliases: _cityAliases[city] ?? const []);
        if (s > 0) add(NeedHit(type: 'bus', city: place.city, from: place.from, dayOffset: day, score: s + 6, fare: place.fare, departures: place.departures));
      }
    }

    // A partner restaurant or shop by name.
    if (context.services.contains('food')) {
      for (final StorePlace store in context.stores) {
        final String name = normalize(store.name);
        if (name.length < 2) continue;
        final List<String> nameWords = name.split(' ');
        int s = (q.length >= 3 && name.startsWith(q)) ? 14 : _phraseScore(q, tokens, name);
        // Every word typed is in the name, in any order: "bon gout" for "Le Bon Goût".
        final List<String> typed = tokens.where((t) => t.length >= 3).toList();
        if (s == 0 && typed.isNotEmpty && typed.every((t) => nameWords.any((w) => w == t || (t == tokens.last && w.startsWith(t))))) s = 10;
        if (s > 0) add(NeedHit(type: 'store', storeId: store.id, title: store.name, open: store.openNow, score: s + 3));
      }
    }

    // Needs, from the word list (and the admin's extra words).
    for (final _Lexeme lex in _lexicon) {
      int s = 0;
      for (final String w in lex.words) {
        s = math.max(s, _phraseScore(q, tokens, w));
        if (s >= 12) break;
      }
      if (s == 0) continue;
      for (final _Target t in lex.targets) {
        if (!_available(t)) continue;
        add(NeedHit(type: t.type, id: t.id, score: s + t.bonus, query: _rest(tokens, lex)));
      }
    }

    final List<NeedHit> hits = best.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    // A city found means a bus trip: plain "bus tickets", and "tomorrow" read as
    // a ride for later, are then beside the point.
    if (hits.any((h) => h.type == 'bus' && h.city != null)) hits.removeWhere((h) => (h.type == 'bus' && h.city == null) || h.type == 'ride_later');
    return hits.take(limit).toList();
  }

  /// "Ask E-Ride" fits a question, or anything a need was found for.
  bool looksLikeQuestion(String text) {
    final String q = normalize(text);
    if (text.contains('?')) return true;
    final List<String> tokens = q.split(' ');
    if (tokens.length >= 4) return true;
    return _questionStarts.any((s) => q == s || q.startsWith('$s '));
  }

  bool _available(_Target t) {
    final String? service = serviceOf(t.type);
    if (service != null && !context.services.contains(service)) return false;
    if (t.type == 'explore' && t.id != null) return context.exploreKeys.contains(t.id);
    return true;
  }

  /// The service a button type belongs to, as the app lists them (null: always there).
  static String? serviceOf(String type) => switch (type) {
        'ride' || 'ride_later' => 'ride',
        'health_ride' => 'health',
        'parcel' => 'parcel',
        'move' => 'move',
        'food' || 'store' => 'food',
        'bus' => 'bus',
        'hotels' => 'hotels',
        'explore' || 'things' => 'explore',
        'market' => 'market',
        'jobs' => 'jobs',
        _ => null,
      };

  /// What is left once the need's own words are taken out: "phone" from
  /// "buy phone", "driver" from "driver job". Null when nothing is left.
  String? _rest(List<String> tokens, _Lexeme lex) {
    if (!lex.keepsQuery) return null;
    final Set<String> drop = {..._fillers, ...lex.generic};
    final List<String> left = tokens.where((t) => !drop.contains(t)).toList();
    return left.isEmpty ? null : left.join(' ');
  }

  // ------------------------------------------------------------------ scoring

  /// 12 for the whole phrase, 10 for a word typed in full, 6 for a word still
  /// being typed (at least 3 letters), 4 for one slip in a word of 5 or more.
  static int _phraseScore(String q, List<String> tokens, String phrase, {List<String> aliases = const []}) {
    if (phrase.isEmpty) return 0;
    for (final String a in aliases) {
      if (tokens.contains(a)) return 10;
    }
    if (phrase.contains(' ')) {
      if (' $q '.contains(' $phrase ')) return 12;
      // The phrase still being typed, at the end of the text: "pharmacie de g".
      final String tail = tokens.sublist(math.max(0, tokens.length - phrase.split(' ').length)).join(' ');
      if (tail.contains(' ') && tail.length >= 5 && phrase.startsWith(tail)) return 6;
      return 0;
    }
    int best = 0;
    for (int i = 0; i < tokens.length; i++) {
      final String t = tokens[i];
      if (t == phrase) return 10;
      final bool last = i == tokens.length - 1;
      if (last && t.length >= 3 && phrase.startsWith(t) && phrase.length - t.length <= 8) best = math.max(best, 6);
      if (t.length >= 5 && phrase.length >= 5 && (t.length - phrase.length).abs() <= 1 && _oneSlip(t, phrase)) best = math.max(best, 4);
    }
    return best;
  }

  /// True when a and b differ by one letter added, removed, changed, or two
  /// neighbours swapped ("pharmcie", "hospitl", "restaurnt").
  static bool _oneSlip(String a, String b) {
    if (a == b) return true;
    if (a.length == b.length) {
      final List<int> diff = [for (int i = 0; i < a.length; i++) if (a[i] != b[i]) i];
      if (diff.length == 1) return true;
      return diff.length == 2 && diff[1] == diff[0] + 1 && a[diff[0]] == b[diff[1]] && a[diff[1]] == b[diff[0]];
    }
    final String longer = a.length > b.length ? a : b;
    final String shorter = a.length > b.length ? b : a;
    for (int i = 0; i < longer.length; i++) {
      if (longer.substring(0, i) + longer.substring(i + 1) == shorter) return true;
    }
    return false;
  }

  /// 0 today, 1 tomorrow, 2 the day after; null when no day is named.
  static int? _dayOffset(String q) {
    final String s = ' $q ';
    if (_afterTomorrow.any((w) => s.contains(' $w '))) return 2;
    if (_tomorrow.any((w) => s.contains(' $w '))) return 1;
    if (_today.any((w) => s.contains(' $w '))) return 0;
    return null;
  }

  /// Lower case, no accents, letters and digits only, single spaces.
  static String normalize(String text) {
    final StringBuffer out = StringBuffer();
    for (final int rune in text.toLowerCase().runes) {
      final String c = String.fromCharCode(rune);
      out.write(_accents[c] ?? (RegExp(r'[a-z0-9]').hasMatch(c) ? c : ' '));
    }
    return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', "'": ' ', '’': ' ',
  };

  static const List<String> _today = ['today', 'aujourd hui', 'aujourdhui', 'tonight', 'ce soir', 'now', 'maintenant', 'tide'];
  static const List<String> _tomorrow = ['tomorrow', 'tomorow', 'tmrw', 'tmr', 'demain', 'tumoro', 'tumora'];
  static const List<String> _afterTomorrow = ['after tomorrow', 'apres demain', 'apres-demain', 'next tomorrow', 'next tumoro'];
  static const Map<String, List<String>> _cityAliases = {
    'douala': ['dla'], 'yaounde': ['yde', 'yaunde'], 'bamenda': ['bda'], 'limbe': ['victoria'], 'bafoussam': ['baf'],
  };
  static const List<String> _fillers = [
    'a', 'an', 'the', 'i', 'me', 'my', 'to', 'for', 'in', 'at', 'of', 'and', 'want', 'need', 'some', 'un', 'une', 'des', 'le', 'la', 'les',
    'de', 'du', 'pour', 'je', 'veux', 'cherche', 'besoin', 'mon', 'ma', 'mes', 'di', 'go', 'fit', 'wan', 'find', 'looking', 'search',
  ];
  static const List<String> _questionStarts = [
    'how', 'what', 'where', 'when', 'why', 'which', 'can i', 'can you', 'do you', 'is there', 'how much', 'comment', 'pourquoi', 'quand',
    'ou', 'quel', 'quelle', 'combien', 'est ce', 'puis je', 'wetin', 'weti', 'how di', 'na how', 'which side', 'how i fit', 'i fit',
  ];

  static List<_Lexeme> _buildLexicon(List<SearchWords> extra) => [
        ..._builtIn,
        for (final SearchWords set in extra)
          _Lexeme(words: [for (final w in set.words) normalize(w)].where((w) => w.length >= 2).toList(), targets: [_Target(set.type, set.id, 1)],
              keepsQuery: set.type == 'market' || set.type == 'jobs'),
      ];

  static final List<_Lexeme> _builtIn = [
    _Lexeme(targets: const [_Target('explore', 'pharmacy', 2), _Target('health_ride', null, -3)], words: const [
      'pharmacy', 'pharmacies', 'pharmacie', 'pharma', 'chemist', 'drugstore', 'drug store', 'medicine', 'medicines', 'medicament',
      'medicaments', 'medoc', 'medocs', 'on duty', 'de garde', 'pharmacie de garde', 'pharmacy on duty', 'drugs', 'paracetamol', 'panadol',
    ]),
    _Lexeme(targets: const [_Target('explore', 'health', 2), _Target('health_ride', null, -2)], words: const [
      'hospital', 'hospitals', 'hopital', 'hopitaux', 'clinic', 'clinics', 'clinique', 'doctor', 'docteur', 'medecin', 'health centre',
      'health center', 'centre de sante', 'dispensary', 'dispensaire', 'maternity', 'maternite', 'dentist', 'dentiste', 'laboratory',
      'laboratoire', 'labo', 'sick', 'malade', 'nurse', 'infirmier', 'infirmiere', 'consultation', 'no well',
    ]),
    _Lexeme(targets: const [_Target('health_ride', null, 4)], words: const [
      'urgent', 'urgence', 'urgences', 'emergency', 'ambulance', 'accident', 'injured', 'blesse', 'health ride', 'course sante', 'emergency ride', 'course d urgence', 'course durgence',
    ]),
    _Lexeme(targets: const [_Target('explore', 'bank', 2)], words: const [
      'bank', 'banks', 'banque', 'banques', 'atm', 'atms', 'gab', 'guichet', 'distributeur', 'cash point', 'cashpoint', 'withdraw',
      'withdrawal', 'retrait', 'retirer', 'afriland', 'ecobank', 'uba', 'sgc', 'sgbc', 'bicec', 'cca', 'cbc', 'scb', 'express union',
      'commercial bank', 'microfinance', 'credit du sahel',
    ]),
    _Lexeme(targets: const [_Target('explore', 'stay', 2)], words: const [
      'hotel', 'hotels', 'auberge', 'auberges', 'guest house', 'guesthouse', 'motel', 'lodge', 'lodging', 'inn', 'chambre', 'chambres',
      'hotel room', 'room for the night', 'sleep', 'dormir', 'nuitee', 'overnight', 'where to sleep', 'place to sleep', 'resort',
    ]),
    _Lexeme(targets: const [_Target('explore', 'homes', 2)], words: const [
      'rent', 'renting', 'for rent', 'to rent', 'a louer', 'louer', 'location', 'house', 'houses', 'maison', 'apartment', 'appartement',
      'appart', 'studio', 'studios', 'flat', 'room to rent', 'chambre a louer', 'land', 'terrain', 'shop to rent', 'boutique a louer',
      'office space', 'bureau a louer', 'self contain', 'self contained', 'modern room', 'landlord', 'bailleur',
    ]),
    _Lexeme(targets: const [_Target('bus', null, 2)], words: const [
      'bus', 'buses', 'agence', 'agences', 'agency', 'agencies', 'travel', 'travelling', 'traveling', 'voyage', 'voyager', 'travel agency',
      'agence de voyage', 'ticket', 'tickets', 'billet', 'billets', 'coach', 'interurbain', 'seat', 'siege',
    ]),
    _Lexeme(targets: const [_Target('food', null, 2)], words: const [
      'food', 'foods', 'chop', 'eat', 'manger', 'nourriture', 'repas', 'meal', 'meals', 'restaurant', 'restaurants', 'resto', 'snack',
      'fast food', 'lunch', 'dinner', 'diner', 'dejeuner', 'breakfast', 'petit dejeuner', 'hungry', 'faim', 'pizza', 'burger', 'shawarma',
      'chicken', 'poulet', 'poulet dg', 'ndole', 'eru', 'achu', 'koki', 'fufu', 'garri', 'okok', 'kati kati', 'kwacoco', 'mbongo',
      'poisson braise', 'fish', 'soya', 'suya', 'beignet', 'beignets', 'puff puff', 'bobolo', 'plantain', 'rice', 'riz', 'spaghetti',
      'sandwich', 'bread', 'pain', 'cake', 'gateau', 'drink', 'drinks', 'boisson', 'boissons', 'juice', 'jus', 'bakery', 'boulangerie',
      'patisserie', 'supermarket', 'supermarche', 'groceries', 'shop', 'shops', 'deliver food', 'food delivery',
    ]),
    _Lexeme(targets: const [_Target('market', null, 1)], keepsQuery: true, generic: const [
      'buy', 'sell', 'selling', 'acheter', 'vendre', 'vente', 'achat', 'market', 'marche', 'marketplace', 'for', 'sale', 'a', 'second', 'hand', 'occasion',
    ], words: const [
      'buy', 'sell', 'selling', 'acheter', 'vendre', 'vente', 'achat', 'market', 'marche', 'marketplace', 'second hand', 'occasion',
      'for sale', 'a vendre', 'phone', 'phones', 'telephone', 'smartphone', 'iphone', 'samsung', 'tecno', 'itel', 'infinix', 'laptop',
      'ordinateur', 'computer', 'tv', 'tele', 'television', 'fridge', 'frigo', 'refrigerateur', 'freezer', 'congelateur', 'furniture',
      'meuble', 'meubles', 'chair', 'chaise', 'table', 'bed', 'lit', 'matelas', 'mattress', 'shoes', 'chaussures', 'clothes', 'habits',
      'vetements', 'dress', 'robe', 'bag', 'sac', 'watch', 'montre', 'generator', 'groupe electrogene', 'motorbike', 'moto', 'fabric',
      'pagne', 'tissu', 'braids', 'tresses', 'hairdresser', 'coiffure', 'tailor', 'couturier', 'repair', 'reparation',
    ]),
    _Lexeme(targets: const [_Target('jobs', null, 2)], keepsQuery: true, generic: const [
      'job', 'jobs', 'work', 'travail', 'emploi', 'emplois', 'boulot', 'djob', 'offer', 'offre', 'd', 'hiring', 'vacancy', 'vacancies',
    ], words: const [
      'job', 'jobs', 'work', 'worker', 'travail', 'travailler', 'emploi', 'emplois', 'boulot', 'djob', 'job offer', 'offre d emploi',
      'hiring', 'recrute', 'recrutement', 'vacancy', 'vacancies', 'cv', 'resume', 'internship', 'stage', 'stagiaire', 'employer',
      'employeur', 'salary', 'salaire', 'find work', 'chercher du travail',
    ]),
    _Lexeme(targets: const [_Target('parcel', null, 2)], words: const [
      'parcel', 'parcels', 'colis', 'package', 'paquet', 'send', 'envoyer', 'envoi', 'courier', 'coursier', 'document', 'documents',
      'send something', 'deliver', 'delivery', 'livrer', 'livraison',
    ]),
    _Lexeme(targets: const [_Target('move', null, 2)], words: const [
      'move', 'moving', 'demenager', 'demenagement', 'truck', 'trucks', 'camion', 'camions', 'pickup', 'pick up', 'dyna', 'tricycle',
      'tricycles', 'van', 'transport goods', 'transporter', 'goods', 'marchandises', 'load',
    ]),
    _Lexeme(targets: const [_Target('ride_later', null, 1)], words: const [
      'later', 'plus tard', 'tomorrow', 'demain', 'schedule', 'scheduled', 'programmer', 'reserver', 'reservation', 'book ahead',
      'airport', 'aeroport', 'early morning', 'tumoro',
    ]),
    _Lexeme(targets: const [_Target('id_verify', null, 1)], words: const [
      'id card', 'identity', 'identite', 'cni', 'carte d identite', 'passport', 'passeport', 'verify', 'verified', 'verification',
      'badge', 'kyc', 'eride id', 'e ride id',
    ]),
    _Lexeme(targets: const [_Target('activity', null, 1)], words: const [
      'my order', 'my orders', 'ma commande', 'mes commandes', 'my ride', 'ma course', 'my ticket', 'mon billet', 'my booking',
      'ma reservation', 'where is my', 'ou est ma', 'ou est mon', 'track', 'suivre', 'status', 'history', 'historique',
    ]),
    _Lexeme(targets: const [_Target('support', null, 0)], words: const [
      'support', 'customer service', 'customer care', 'service client', 'complain', 'complaint', 'plainte', 'problem', 'probleme',
      'issue', 'contact', 'call center', 'whatsapp', 'reclamation',
    ]),
  ];
}

/// What the app knows right now: the services on, Explore's categories, bus
/// destinations, partner stores, and the admin's extra words.
class NeedContext {
  final Set<String> services;
  final Set<String> exploreKeys;
  final List<BusPlace> busPlaces;
  final List<StorePlace> stores;
  final List<SearchWords> extraWords;

  const NeedContext({
    required this.services,
    this.exploreKeys = const {},
    this.busPlaces = const [],
    this.stores = const [],
    this.extraWords = const [],
  });
}

class BusPlace {
  final String city;
  final String from;
  final double? fare;
  final int departures;
  const BusPlace({required this.city, required this.from, this.fare, this.departures = 0});
}

class StorePlace {
  final String id;
  final String name;
  final bool openNow;
  const StorePlace({required this.id, required this.name, this.openNow = true});
}

class SearchWords {
  final String type;
  final String? id;
  final List<String> words;
  const SearchWords({required this.type, this.id, required this.words});
}

/// One suggestion: a button type (as in Ask E-Ride), or "store" for a partner
/// store, with what it needs to open the right screen.
class NeedHit {
  final String type;
  final String? id;
  final int score;

  /// Market and Jobs: the words left to search for ("phone").
  final String? query;

  /// Bus: the destination, its origin, the day (0 today, 1 tomorrow) and the cheapest fare.
  final String? city;
  final String? from;
  final int? dayOffset;
  final double? fare;
  final int departures;

  /// Store: its id and name, and whether it is open now.
  final String? storeId;
  final String? title;
  final bool open;

  const NeedHit({
    required this.type,
    this.id,
    required this.score,
    this.query,
    this.city,
    this.from,
    this.dayOffset,
    this.fare,
    this.departures = 0,
    this.storeId,
    this.title,
    this.open = true,
  });

  @override
  String toString() => 'NeedHit($type${id != null ? ':$id' : ''}${city != null ? ' to $city' : ''}${storeId != null ? ' store $title' : ''}'
      '${query != null ? ' "$query"' : ''}${dayOffset != null ? ' +$dayOffset' : ''}, $score)';
}

class _Lexeme {
  final List<String> words;
  final List<_Target> targets;

  /// Market and Jobs search for the words left over ("phone", "driver").
  final bool keepsQuery;

  /// Words that only say "Market" or "Jobs", left out of that search.
  final List<String> generic;

  const _Lexeme({required this.words, required this.targets, this.keepsQuery = false, this.generic = const []});
}

class _Target {
  final String type;
  final String? id;

  /// Order among targets of the same words: the place before the ride there.
  final int bonus;
  const _Target(this.type, this.id, this.bonus);
}

/// An info sheet (GET /api/customer/assistant/help): a title and a few steps.
class HelpSheet {
  final String key;
  final String title;
  final List<String> steps;

  const HelpSheet({required this.key, required this.title, required this.steps});

  factory HelpSheet.fromJson(Map<String, dynamic> json) => HelpSheet(
        key: json['key']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        steps: ((json['steps'] as List?) ?? []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {'key': key, 'title': title, 'steps': steps};
}

/// A "Did you know?" card for Home, from the knowledge pack: a headline, one
/// line, and the button into the service it is about.
class AssistantTip {
  final String key;
  final String? service;
  final String title;
  final String body;
  final AssistantAction action;

  const AssistantTip({required this.key, this.service, required this.title, required this.body, required this.action});

  factory AssistantTip.fromJson(Map<String, dynamic> json) => AssistantTip(
        key: json['key']?.toString() ?? '',
        service: json['service']?.toString(),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        action: AssistantAction.fromJson(Map<String, dynamic>.from((json['action'] as Map?) ?? const {})),
      );
}

/// Words the admin added for the smart search, and the button they lead to.
class SearchWordSet {
  final String type;
  final String? id;
  final List<String> words;

  const SearchWordSet({required this.type, this.id, required this.words});

  factory SearchWordSet.fromJson(Map<String, dynamic> json) => SearchWordSet(
        type: json['type']?.toString() ?? '',
        id: json['id']?.toString(),
        words: ((json['words'] as List?) ?? []).map((e) => e.toString()).toList(),
      );
}

/// A button in an answer: opens a screen of the app (or WhatsApp support).
class AssistantAction {
  /// ride, ride_later, health_ride, parcel, move, food, bus, hotels, explore,
  /// market, jobs, activity, order, bus_booking, hotel_chat, id_verify, support.
  final String type;
  final String label;
  final String? id;

  const AssistantAction({required this.type, required this.label, this.id});

  factory AssistantAction.fromJson(Map<String, dynamic> json) => AssistantAction(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        id: json['id']?.toString(),
      );
}

/// Something E-Ride really has that matches the question (Market item or
/// shop, a store or dish, a place, a tour, a job, a home, a bus): shown as a
/// card in the answer, it opens the thing itself.
class AssistantCard {
  /// market_item, market_shop, store, place, tour, job, listing, bus.
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final double? price;
  final String? photo;
  /// For places: the full card, so the place page opens without another request.
  final Map<String, dynamic>? place;

  const AssistantCard({required this.type, required this.id, required this.title, this.subtitle = '', this.price, this.photo, this.place});

  factory AssistantCard.fromJson(Map<String, dynamic> json) {
    final String? photo = json['photo']?.toString();
    return AssistantCard(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      price: json['price'] == null ? null : double.tryParse('${json['price']}'),
      photo: photo == null || photo.isEmpty ? null : photo,
      place: json['place'] is Map ? Map<String, dynamic>.from(json['place']) : null,
    );
  }
}

/// One line of the conversation.
class AssistantMessage {
  final bool fromUser;
  final String text;
  final List<AssistantAction> actions;
  /// What E-Ride has for the question, best first.
  final List<AssistantCard> cards;
  /// The logged question, for 👍/👎.
  final String? questionId;
  bool? helped;
  /// "How do I..." answers: the way, step by step.
  final List<String> steps;
  /// Questions this customer would likely ask next, as chips.
  final List<String> followUps;

  AssistantMessage({required this.fromUser, required this.text, this.actions = const [], this.cards = const [], this.questionId, this.helped,
    this.steps = const [], this.followUps = const []});
}

/// What a voice note recorded while booking became: the recording the driver
/// will hear, and (when the AI could listen) what the customer said, where to
/// find them, where they go and, for a parcel, what they send.
class VoiceTripResult {
  /// The recording's name on the server, sent with the booking.
  final String name;
  final String url;
  final int seconds;
  /// The recording on this phone, to play it back without downloading.
  final String localPath;
  final bool understood;
  final String transcript;
  final String pickup;
  final String destination;
  final String note;
  final VoiceParcel? parcel;

  const VoiceTripResult({required this.name, required this.url, required this.seconds, required this.localPath, this.understood = false,
    this.transcript = '', this.pickup = '', this.destination = '', this.note = '', this.parcel});

  factory VoiceTripResult.fromJson(Map<String, dynamic> json, String localPath) => VoiceTripResult(
        name: json['voice_note']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        seconds: int.tryParse('${json['seconds']}') ?? 0,
        localPath: localPath,
        understood: json['understood'] == true,
        transcript: json['transcript']?.toString() ?? '',
        pickup: json['pickup']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
        parcel: json['parcel'] is Map ? VoiceParcel.fromJson(Map<String, dynamic>.from(json['parcel'])) : null,
      );

  /// What the driver reads with the note: where to find the customer, then anything else.
  String get driverText => [pickup, note].where((s) => s.trim().isNotEmpty).join('. ');
}

class VoiceParcel {
  final String what;
  final double? weightKg;
  final bool fragile;
  final String receiverName;
  final String receiverPhone;
  final String category;

  const VoiceParcel({this.what = '', this.weightKg, this.fragile = false, this.receiverName = '', this.receiverPhone = '', this.category = ''});

  factory VoiceParcel.fromJson(Map<String, dynamic> json) => VoiceParcel(
        what: json['what']?.toString() ?? '',
        weightKg: json['weight_kg'] == null ? null : double.tryParse('${json['weight_kg']}'),
        fragile: json['fragile'] == true,
        receiverName: json['receiver_name']?.toString() ?? '',
        receiverPhone: json['receiver_phone']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
      );
}

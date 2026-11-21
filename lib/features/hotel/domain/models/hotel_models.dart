import 'package:ride_sharing_user_app/util/app_constants.dart';

String? _text(dynamic v) {
  final String? s = v?.toString().trim();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}

int? _int(dynamic v) => v == null ? null : int.tryParse('$v');
double? _double(dynamic v) => v == null ? null : double.tryParse('$v');
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// A photo path from the server: absolute, or under the API base.
String hotelImage(String url) => url.startsWith('http') ? url : '${AppConstants.baseUrl}/$url';

/// The partner part of a hotel: how fast it answers, and (when its rooms are up to date) how many are free.
class HotelPartnerInfo {
  final String hotelId;
  final int? answerMinutes;
  final bool fresh;
  final int? priceFrom;
  /// Null when the hotel has not updated its rooms lately: "Ask the reception".
  final int? freeRooms;
  final String? receptionPhone;
  final String checkInFrom;
  final String checkOutBy;
  final bool answersNow;

  const HotelPartnerInfo({required this.hotelId, this.answerMinutes, this.fresh = false, this.priceFrom, this.freeRooms,
      this.receptionPhone, this.checkInFrom = '12:00', this.checkOutBy = '11:00', this.answersNow = true});

  factory HotelPartnerInfo.fromJson(Map<String, dynamic> j) => HotelPartnerInfo(
        hotelId: '${j['hotel_id']}',
        answerMinutes: _int(j['answer_minutes']),
        fresh: j['fresh'] == true,
        priceFrom: _int(j['price_from']),
        freeRooms: _int(j['free_rooms']),
        receptionPhone: _text(j['reception_phone']),
        checkInFrom: _text(j['check_in_from']) ?? '12:00',
        checkOutBy: _text(j['check_out_by']) ?? '11:00',
        answersNow: j['answers_now'] != false,
      );
}

class HotelRoomType {
  final String id;
  final String name;
  final String? beds;
  final int maxGuests;
  final int priceFrom;
  final List<String> amenities;
  final String? description;
  final List<String> photos;
  /// Null when the counts are not trustworthy right now.
  final int? free;

  const HotelRoomType({required this.id, required this.name, this.beds, this.maxGuests = 2, this.priceFrom = 0,
      this.amenities = const [], this.description, this.photos = const [], this.free});

  factory HotelRoomType.fromJson(Map<String, dynamic> j) => HotelRoomType(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        beds: _text(j['beds']),
        maxGuests: _int(j['max_guests']) ?? 2,
        priceFrom: _int(j['price_from']) ?? 0,
        amenities: ((j['amenities'] as List?) ?? []).map((e) => '$e').toList(),
        description: _text(j['description']),
        photos: ((j['photos'] as List?) ?? []).map((e) => hotelImage('$e')).toList(),
        free: _int(j['free']),
      );
}

class HotelDetail {
  final String id;
  final String placeId;
  final String name;
  final String category;
  final String? description;
  final String address;
  final double? latitude;
  final double? longitude;
  final List<String> photos;
  final List<String> amenities;
  final DateTime checkIn;
  final DateTime checkOut;
  final HotelPartnerInfo partner;
  final List<HotelRoomType> roomTypes;
  final String? openInquiryId;
  final int maxRooms;
  final int maxNights;
  final int daysAhead;

  const HotelDetail({required this.id, required this.placeId, required this.name, required this.category, this.description,
      required this.address, this.latitude, this.longitude, this.photos = const [], this.amenities = const [], required this.checkIn,
      required this.checkOut, required this.partner, this.roomTypes = const [], this.openInquiryId, this.maxRooms = 5, this.maxNights = 30, this.daysAhead = 120});

  bool get hasLocation => latitude != null && longitude != null;

  factory HotelDetail.fromJson(Map<String, dynamic> j) {
    final limits = j['limits'] is Map ? Map<String, dynamic>.from(j['limits']) : <String, dynamic>{};
    return HotelDetail(
      id: '${j['id']}',
      placeId: '${j['place_id']}',
      name: '${j['name'] ?? ''}',
      category: '${j['category'] ?? 'hotel'}',
      description: _text(j['description']),
      address: '${j['address'] ?? ''}',
      latitude: _double(j['latitude']),
      longitude: _double(j['longitude']),
      photos: ((j['photos'] as List?) ?? []).map((e) => hotelImage('$e')).toList(),
      amenities: ((j['amenities'] as List?) ?? []).map((e) => '$e').toList(),
      checkIn: DateTime.tryParse('${j['check_in']}') ?? DateTime.now(),
      checkOut: DateTime.tryParse('${j['check_out']}') ?? DateTime.now().add(const Duration(days: 1)),
      partner: HotelPartnerInfo.fromJson(Map<String, dynamic>.from(j['partner'] ?? {})),
      roomTypes: ((j['room_types'] as List?) ?? []).whereType<Map>().map((e) => HotelRoomType.fromJson(Map<String, dynamic>.from(e))).toList(),
      openInquiryId: _text(j['open_inquiry_id']),
      maxRooms: _int(limits['max_rooms']) ?? 5,
      maxNights: _int(limits['max_nights']) ?? 30,
      daysAhead: _int(limits['days_ahead']) ?? 120,
    );
  }
}

class HotelMessage {
  final int id;
  /// guest | hotel | system
  final String sender;
  /// text | request | price | kept | released | arrived | closed
  final String kind;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? at;

  const HotelMessage({required this.id, required this.sender, required this.kind, this.body, this.data = const {}, this.at});

  bool get mine => sender == 'guest';

  factory HotelMessage.fromJson(Map<String, dynamic> j) => HotelMessage(
        id: _int(j['id']) ?? 0,
        sender: '${j['sender'] ?? 'system'}',
        kind: '${j['kind'] ?? 'text'}',
        body: _text(j['body']),
        data: j['data'] is Map ? Map<String, dynamic>.from(j['data']) : const {},
        at: _date(j['at']),
      );
}

class HotelBrief {
  final String id;
  final String placeId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? photo;
  final String? receptionPhone;
  final int? answerMinutes;
  final bool answersNow;

  const HotelBrief({required this.id, required this.placeId, required this.name, this.address, this.latitude, this.longitude,
      this.photo, this.receptionPhone, this.answerMinutes, this.answersNow = true});

  bool get hasLocation => latitude != null && longitude != null;

  factory HotelBrief.fromJson(Map<String, dynamic> j) => HotelBrief(
        id: '${j['id']}',
        placeId: '${j['place_id']}',
        name: '${j['name'] ?? ''}',
        address: _text(j['address']),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        photo: _text(j['photo']) == null ? null : hotelImage('${j['photo']}'),
        receptionPhone: _text(j['reception_phone']),
        answerMinutes: _int(j['answer_minutes']),
        answersNow: j['answers_now'] != false,
      );
}

/// A question to a hotel and its chat.
class HotelInquiry {
  final String id;
  /// open | answered | kept | arrived | closed
  final String status;
  /// guest | full | didnt_come | expired | stayed | hotel
  final String? closeReason;
  final HotelBrief hotel;
  final String? roomTypeName;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final int guests;
  final int rooms;
  final String? arrival;
  final int? price;
  final DateTime? keptUntil;
  final int keptRooms;
  final bool onTheWay;
  final int unread;
  final DateTime? lastMessageAt;
  final HotelMessage? lastMessage;
  final List<HotelMessage> messages;

  const HotelInquiry({required this.id, required this.status, this.closeReason, required this.hotel, this.roomTypeName, required this.checkIn,
      required this.checkOut, this.nights = 1, this.guests = 1, this.rooms = 1, this.arrival, this.price, this.keptUntil, this.keptRooms = 0,
      this.onTheWay = false, this.unread = 0, this.lastMessageAt, this.lastMessage, this.messages = const []});

  bool get isActive => status != 'closed';
  bool get isKept => status == 'kept' && keptUntil != null;

  HotelInquiry withMessages(List<HotelMessage> all) => HotelInquiry(
        id: id, status: status, closeReason: closeReason, hotel: hotel, roomTypeName: roomTypeName, checkIn: checkIn, checkOut: checkOut,
        nights: nights, guests: guests, rooms: rooms, arrival: arrival, price: price, keptUntil: keptUntil, keptRooms: keptRooms,
        onTheWay: onTheWay, unread: unread, lastMessageAt: lastMessageAt, lastMessage: all.isEmpty ? lastMessage : all.last, messages: all);

  factory HotelInquiry.fromJson(Map<String, dynamic> j) => HotelInquiry(
        id: '${j['id']}',
        status: '${j['status'] ?? 'open'}',
        closeReason: _text(j['close_reason']),
        hotel: HotelBrief.fromJson(Map<String, dynamic>.from(j['hotel'] ?? {})),
        roomTypeName: j['room_type'] is Map ? _text(j['room_type']['name']) : null,
        checkIn: DateTime.tryParse('${j['check_in']}') ?? DateTime.now(),
        checkOut: DateTime.tryParse('${j['check_out']}') ?? DateTime.now(),
        nights: _int(j['nights']) ?? 1,
        guests: _int(j['guests']) ?? 1,
        rooms: _int(j['rooms']) ?? 1,
        arrival: _text(j['arrival']),
        price: _int(j['price']),
        keptUntil: _date(j['kept_until']),
        keptRooms: _int(j['kept_rooms']) ?? 0,
        onTheWay: j['on_the_way'] == true,
        unread: _int(j['unread']) ?? 0,
        lastMessageAt: _date(j['last_message_at']),
        lastMessage: j['last_message'] is Map ? HotelMessage.fromJson(Map<String, dynamic>.from(j['last_message'])) : null,
        messages: ((j['messages'] as List?) ?? []).whereType<Map>().map((e) => HotelMessage.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

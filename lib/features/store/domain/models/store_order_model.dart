/// A Food & Shops order. Status values mirror the backend's StoreOrder
/// constants (Modules/StoreManagement/Entities/StoreOrder.php).
class StoreOrderModel {
  /// Sent: the restaurant confirms, suggests changes or declines. Nothing paid yet.
  static const String awaitingConfirmation = 'awaiting_confirmation';
  /// The restaurant suggested changes: accept (then pay) or cancel.
  static const String changesProposed = 'changes_proposed';
  /// Confirmed ([confirmedAt] set): pay by [payBy]. Older pay-first orders have no confirmedAt.
  static const String awaitingPayment = 'awaiting_payment';
  static const String placed = 'placed';
  static const String accepted = 'accepted';
  static const String riderRequested = 'rider_requested';
  static const String pickedUp = 'picked_up';
  static const String delivered = 'delivered';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';
  static const String deliveryFailed = 'delivery_failed';

  String id;
  int? ref;
  String status;
  String? paymentStatus;
  String? paymentMethod;
  String? storeId;
  String? storeName;
  String? storeLogo;
  String? storePhone;
  List<StoreOrderLine> items;
  int itemsCount;
  double itemsSubtotal;
  double deliveryFee;
  double total;
  double refundedAmount;
  String? dropAddress;
  String? receiverName;
  String? receiverPhone;
  String? note;
  int? prepMinutes;
  DateTime? readyAt;
  String? tripRequestId;
  String? tripStatus;
  String? riderId;
  String? riderName;
  String? riderPhone;
  String? riderImage;
  /// Kept after delivery (riderName is not), for the rating card.
  String? riderFirstName;
  bool canReview;
  StoreOrderReview? review;
  /// delivery, dine_in (eat there) or pickup (collect).
  String fulfilment = 'delivery';
  DateTime? arriveAt;
  int? guests;
  /// Shown at the restaurant once paid, until handed over.
  String? collectCode;
  bool readyTold = false;
  String? storeAddress;
  double? storeLatitude;
  double? storeLongitude;
  /// "Deliver it instead" is still possible.
  bool canDeliver = false;
  /// A change to delivery waiting for its fee: fee, address, pay by.
  double? deliveryChangeFee;
  String? deliveryChangeAddress;
  DateTime? deliveryChangePayBy;
  /// The delivery fee's page, to open again after leaving it unpaid.
  String? deliveryChangePayUrl;
  bool get isDelivery => fulfilment == 'delivery';
  bool get isDineIn => fulfilment == 'dine_in';
  bool get isPickup => fulfilment == 'pickup';
  String? cancelReason;
  bool canCancel;
  DateTime? createdAt;
  DateTime? placedAt;
  DateTime? acceptedAt;
  DateTime? riderRequestedAt;
  DateTime? pickedUpAt;
  DateTime? deliveredAt;
  DateTime? cancelledAt;
  /// Who has to act before payment, and by when.
  DateTime? respondBy;
  DateTime? answerBy;
  DateTime? payBy;
  DateTime? confirmedAt;
  StoreOrderProposal? proposal;

  StoreOrderModel({
    required this.id,
    this.ref,
    required this.status,
    this.paymentStatus,
    this.paymentMethod,
    this.storeId,
    this.storeName,
    this.storeLogo,
    this.storePhone,
    this.items = const [],
    this.itemsCount = 0,
    this.itemsSubtotal = 0,
    this.deliveryFee = 0,
    this.total = 0,
    this.refundedAmount = 0,
    this.dropAddress,
    this.receiverName,
    this.receiverPhone,
    this.note,
    this.prepMinutes,
    this.readyAt,
    this.tripRequestId,
    this.tripStatus,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.riderImage,
    this.riderFirstName,
    this.canReview = false,
    this.review,
    this.cancelReason,
    this.canCancel = false,
    this.createdAt,
    this.placedAt,
    this.acceptedAt,
    this.riderRequestedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.respondBy,
    this.answerBy,
    this.payBy,
    this.confirmedAt,
    this.proposal,
  });

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
  static double _num(dynamic v) => double.tryParse('$v') ?? 0;

  factory StoreOrderModel.fromJson(Map<String, dynamic> json) {
    final store = json['store'] is Map ? json['store'] as Map : const {};
    final rider = json['rider'] is Map ? json['rider'] as Map : const {};
    final timeline = json['timeline'] is Map ? json['timeline'] as Map : const {};
    final change = json['delivery_change'] is Map ? json['delivery_change'] as Map : null;
    final place = json['store_place'] is Map ? json['store_place'] as Map : const {};
    return StoreOrderModel(
      id: json['id'].toString(),
      ref: int.tryParse('${json['ref']}'),
      status: json['status'] ?? '',
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'],
      storeId: store['id']?.toString(),
      storeName: store['name'],
      storeLogo: store['logo'],
      storePhone: store['phone'],
      items: ((json['items'] as List?) ?? []).map((e) => StoreOrderLine.fromJson(e)).toList(),
      itemsCount: int.tryParse('${json['items_count']}') ?? 0,
      itemsSubtotal: _num(json['items_subtotal']),
      deliveryFee: _num(json['delivery_fee']),
      total: _num(json['total']),
      refundedAmount: _num(json['refunded_amount']),
      dropAddress: json['drop_address'],
      receiverName: json['receiver_name'],
      receiverPhone: json['receiver_phone'],
      note: json['note'],
      prepMinutes: int.tryParse('${json['prep_minutes']}'),
      readyAt: _date(json['ready_at']),
      tripRequestId: json['trip_request_id']?.toString(),
      tripStatus: json['trip_status'],
      riderId: rider['id']?.toString(),
      riderName: rider['name'],
      riderPhone: rider['phone'],
      riderImage: rider['image'],
      riderFirstName: json['rider_first_name']?.toString(),
      canReview: json['can_review'] == true,
      review: json['review'] is Map ? StoreOrderReview.fromJson(Map<String, dynamic>.from(json['review'])) : null,
      cancelReason: json['cancel_reason'],
      canCancel: json['can_cancel'] == true,
      createdAt: _date(json['created_at']),
      placedAt: _date(timeline['placed_at']),
      acceptedAt: _date(timeline['accepted_at']),
      riderRequestedAt: _date(timeline['rider_requested_at']),
      pickedUpAt: _date(timeline['picked_up_at']),
      deliveredAt: _date(timeline['delivered_at']),
      cancelledAt: _date(timeline['cancelled_at']),
      respondBy: _date(json['respond_by']),
      answerBy: _date(json['answer_by']),
      payBy: _date(json['pay_by']),
      confirmedAt: _date(json['confirmed_at']),
      proposal: json['proposal'] is Map ? StoreOrderProposal.fromJson(Map<String, dynamic>.from(json['proposal'])) : null,
    )
      ..fulfilment = json['fulfilment']?.toString() ?? 'delivery'
      ..arriveAt = _date(json['arrive_at'])
      ..guests = int.tryParse('${json['guests']}')
      ..collectCode = json['collect_code']?.toString()
      ..readyTold = json['ready_told'] == true
      ..storeAddress = place['address']?.toString()
      ..storeLatitude = double.tryParse('${place['latitude']}')
      ..storeLongitude = double.tryParse('${place['longitude']}')
      ..canDeliver = json['can_deliver'] == true
      ..deliveryChangeFee = change == null ? null : double.tryParse('${change['fee']}')
      ..deliveryChangeAddress = change?['address']?.toString()
      ..deliveryChangePayBy = change == null ? null : _date(change['pay_by'])
      ..deliveryChangePayUrl = change?['pay_url']?.toString();
  }

  /// Confirmed by the restaurant, waiting for this customer to pay.
  bool get isConfirmedUnpaid => status == awaitingPayment && confirmedAt != null;
  /// The restaurant and the customer are still agreeing on the order.
  bool get isBeforePayment => status == awaitingConfirmation || status == changesProposed || isConfirmedUnpaid;

  bool get isActive => const [awaitingConfirmation, changesProposed, placed, accepted, riderRequested, pickedUp].contains(status) || isConfirmedUnpaid;
  bool get isClosedUnhappily => const [rejected, cancelled, expired, deliveryFailed].contains(status);

  /// A rider can be followed on the map once one is on the way.
  bool get canTrack => tripRequestId != null && riderName != null && (status == riderRequested || status == pickedUp);
}

/// Changes the restaurant suggests: the order as it would be, line by line.
class StoreOrderProposal {
  final String? note;
  final List<StoreProposalLine> lines;
  final double itemsSubtotal;
  final double total;

  const StoreOrderProposal({this.note, this.lines = const [], this.itemsSubtotal = 0, this.total = 0});

  factory StoreOrderProposal.fromJson(Map<String, dynamic> json) => StoreOrderProposal(
        note: json['note']?.toString(),
        lines: ((json['lines'] as List?) ?? []).map((e) => StoreProposalLine.fromJson(Map<String, dynamic>.from(e))).toList(),
        itemsSubtotal: double.tryParse('${json['items_subtotal']}') ?? 0,
        total: double.tryParse('${json['total']}') ?? 0,
      );
}

class StoreProposalLine {
  /// same, removed, reduced, increased or swapped.
  final String change;
  final String name;
  final int quantity;
  final String wasName;
  final int wasQuantity;
  final double lineTotal;

  const StoreProposalLine({required this.change, required this.name, required this.quantity, required this.wasName, required this.wasQuantity, this.lineTotal = 0});

  factory StoreProposalLine.fromJson(Map<String, dynamic> json) => StoreProposalLine(
        change: json['change']?.toString() ?? 'same',
        name: json['name']?.toString() ?? '',
        quantity: int.tryParse('${json['quantity']}') ?? 0,
        wasName: json['was_name']?.toString() ?? '',
        wasQuantity: int.tryParse('${json['was_quantity']}') ?? 0,
        lineTotal: double.tryParse('${json['line_total']}') ?? 0,
      );
}

/// The customer's rating of a delivered order.
class StoreOrderReview {
  final int storeRating;
  final String? storeComment;
  final int? riderRating;

  const StoreOrderReview({required this.storeRating, this.storeComment, this.riderRating});

  factory StoreOrderReview.fromJson(Map<String, dynamic> json) => StoreOrderReview(
        storeRating: int.tryParse('${json['store_rating']}') ?? 0,
        storeComment: json['store_comment']?.toString(),
        riderRating: int.tryParse('${json['rider_rating']}'),
      );
}

class StoreOrderLine {
  String name;
  int quantity;
  double unitPrice;
  double lineTotal;

  StoreOrderLine({required this.name, required this.quantity, this.unitPrice = 0, this.lineTotal = 0});

  factory StoreOrderLine.fromJson(Map<String, dynamic> json) => StoreOrderLine(
        name: json['name'] ?? '',
        quantity: int.tryParse('${json['quantity']}') ?? 1,
        unitPrice: double.tryParse('${json['unit_price']}') ?? 0,
        lineTotal: double.tryParse('${json['line_total']}') ?? 0,
      );
}

/// POST /api/customer/store-orders/quote
class StoreQuote {
  bool ok;
  List<String> problems;
  double itemsSubtotal;
  double deliveryFee;
  double total;
  double? distanceKm;
  int? durationMin;

  StoreQuote({required this.ok, required this.problems, this.itemsSubtotal = 0, this.deliveryFee = 0, this.total = 0, this.distanceKm, this.durationMin});

  factory StoreQuote.fromJson(Map<String, dynamic> json) => StoreQuote(
        ok: json['ok'] == true,
        problems: ((json['problems'] as List?) ?? []).map((e) => e.toString()).toList(),
        itemsSubtotal: double.tryParse('${json['items_subtotal']}') ?? 0,
        deliveryFee: double.tryParse('${json['delivery_fee']}') ?? 0,
        total: double.tryParse('${json['total']}') ?? 0,
        distanceKm: double.tryParse('${json['distance_km']}'),
        durationMin: int.tryParse('${json['duration_min']}'),
      );
}

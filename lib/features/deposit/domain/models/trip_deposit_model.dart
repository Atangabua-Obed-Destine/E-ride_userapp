/// The booking deposit of an accepted ride or parcel: paid by the customer
/// after a driver accepts, before the driver sets off. Counts toward the fare.
class TripDeposit {
  final double amount;
  final String status;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final String? paymentMethod;
  final double appliedAmount;
  final double refundedAmount;
  final bool cancelIsFree;
  final String? cancelFreeReason;
  final DateTime? freeCancelUntil;

  /// Server clock minus this phone's clock when the deposit was read, so the
  /// countdown follows the server even when the phone's time is off.
  final Duration clockOffset;

  TripDeposit({
    required this.amount,
    required this.status,
    this.dueAt,
    this.paidAt,
    this.paymentMethod,
    this.appliedAmount = 0,
    this.refundedAmount = 0,
    this.cancelIsFree = true,
    this.cancelFreeReason,
    this.freeCancelUntil,
    this.clockOffset = Duration.zero,
  });

  static const String awaiting = 'awaiting';
  static const String paid = 'paid';
  static const String applied = 'applied';
  static const String forfeited = 'forfeited';
  static const String refunded = 'refunded';
  static const String expired = 'expired';

  bool get isAwaiting => status == awaiting;
  bool get isPaid => status == paid;

  DateTime get _serverNow => DateTime.now().add(clockOffset);

  /// Time left to pay (zero once it ran out).
  Duration get timeLeft {
    if (dueAt == null) return Duration.zero;
    final left = dueAt!.difference(_serverNow);
    return left.isNegative ? Duration.zero : left;
  }

  /// Time left to cancel for free after paying (zero when none).
  Duration get freeCancelLeft {
    if (freeCancelUntil == null) return Duration.zero;
    final left = freeCancelUntil!.difference(_serverNow);
    return left.isNegative ? Duration.zero : left;
  }

  static DateTime? _time(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
  static double _num(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

  static TripDeposit? fromJson(dynamic json) {
    if (json is! Map) return null;
    final server = _time(json['server_time']);
    return TripDeposit(
      amount: _num(json['amount']),
      status: json['status']?.toString() ?? '',
      dueAt: _time(json['due_at']),
      paidAt: _time(json['paid_at']),
      paymentMethod: json['payment_method']?.toString(),
      appliedAmount: _num(json['applied_amount']),
      refundedAmount: _num(json['refunded_amount']),
      cancelIsFree: json['cancel_is_free'] != false,
      cancelFreeReason: json['cancel_free_reason']?.toString(),
      freeCancelUntil: _time(json['free_cancel_until']),
      clockOffset: server == null ? Duration.zero : server.difference(DateTime.now()),
    );
  }
}

class ReportReason {
  final String key;
  final String label;
  ReportReason(this.key, this.label);
}

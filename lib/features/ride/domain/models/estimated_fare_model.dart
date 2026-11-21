class EstimatedFareModel {
  String? responseCode;
  String? message;
  List<FareModel>? data;


  EstimatedFareModel(
      {this.responseCode,
        this.message,
        this.data,
       });

  EstimatedFareModel.fromJson(Map<String, dynamic> json) {
    responseCode = json['response_code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <FareModel>[];
      json['data'].forEach((v) {
        data!.add(FareModel.fromJson(v));
      });
    }

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['response_code'] = responseCode;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }

    return data;
  }
}

class FareModel {
  String? id;
  String? zoneId;
  String? vehicleCategoryId;
  String? vehicleCategoryType;
  double? baseFare;
  double? baseFarePerKm;
  double? fare;
  String? estimatedDistance;
  String? estimatedDuration;
  double? estimatedFare;
  double? discountFare;
  double? discountAmount;
  bool?   couponApplicable;
  String? requestType;
  String? polyline;
  String? areaId;
  double? extraEstimatedFare;
  double? extraDiscountFare;
  double? extraDiscountAmount;
  double? extraReturnFee;
  double? extraCancellationFee;
  double? extraFareAmount;
  double? extraFareFee;
  String? extraFareReason;
  double? surgeMultiplier;
  /// Paid after a driver accepts; it counts toward the fare. 0 when none.
  double bookingDeposit = 0;
  /// E-Ride Move rows carry no price, only the deposit.
  bool isMove = false;
  /// Drop fare: a fixed price for this route and vehicle (no surge, no bidding).
  bool isDropFare = false;
  /// Health ride estimate: the normal fare, no surge or extra fare.
  bool isHealthRide = false;
  String? dropFareLabel;
  String? vehicleType;
  /// The pickup or the destination is in an area E-Ride paused for safety (the ride still goes ahead).
  String? safetyNotice;


  FareModel(
      {this.id,
        this.zoneId,
        this.vehicleCategoryId,
        this.vehicleCategoryType,
        this.baseFare,
        this.baseFarePerKm,
        this.fare,
        this.estimatedDistance,
        this.estimatedDuration,
        this.estimatedFare,
        this.requestType,
        this.polyline,
        this.areaId,
        this.discountAmount,
        this.couponApplicable,
        this.discountFare,
        this.extraCancellationFee,
        this.extraDiscountAmount,
        this.extraDiscountFare,
        this.extraEstimatedFare,
        this.extraFareAmount,
        this.extraFareFee,
        this.extraFareReason,
        this.extraReturnFee,
        this.surgeMultiplier
      });

  FareModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    zoneId = json['zone_id'];
    vehicleCategoryId = json['vehicle_category_id'];
    vehicleCategoryType = json['vehicle_category_type'];
    baseFare = double.tryParse(json['base_fare'].toString());
    baseFarePerKm = double.tryParse(json['base_fare_per_km'].toString());
    fare = double.tryParse(json['fare'].toString());
    estimatedDistance = json['estimated_distance'].toString();
    estimatedDuration = json['estimated_duration'].toString();
    estimatedFare = double.tryParse(json['estimated_fare'].toString());
    requestType = json['request type'];
    polyline = json['encoded_polyline'];
    areaId = json['area_id'];
    discountAmount = double.tryParse(json['discount_amount'].toString());
    couponApplicable = json['coupon_applicable'] != null ? (bool.tryParse(json['coupon_applicable'].toString()) ?? (json['coupon_applicable'].toString() == '1')) : null;
    discountFare = double.tryParse(json['discount_fare'].toString());
    extraEstimatedFare = double.tryParse(json['extra_estimated_fare'].toString());
    extraDiscountFare = double.tryParse(json['extra_discount_fare'].toString());
    extraDiscountAmount = double.tryParse(json['extra_discount_amount'].toString());
    extraReturnFee = double.tryParse(json['extra_return_fee'].toString());
    extraCancellationFee = double.tryParse(json['extra_cancellation_fee'].toString());
    extraFareAmount = double.tryParse(json['extra_fare_amount'].toString());
    extraFareFee = double.tryParse(json['extra_fare_fee'].toString());
    extraFareReason = json['extra_fare_reason'];
    surgeMultiplier = double.tryParse(json['surge_multiplier'].toString());
    bookingDeposit = double.tryParse('${json['booking_deposit'] ?? 0}') ?? 0;
    isMove = json['is_move'] == true;
    isDropFare = json['is_drop_fare'] == true;
    isHealthRide = json['is_health_ride'] == true;
    dropFareLabel = json['drop_fare_label']?.toString();
    vehicleType = json['vehicle_type']?.toString();
    final notice = json['safety_notice']?.toString().trim();
    safetyNotice = notice == null || notice.isEmpty ? null : notice;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['zone_id'] = zoneId;
    data['vehicle_category_id'] = vehicleCategoryId;
    data['base_fare'] = baseFare;
    data['base_fare_per_km'] = baseFarePerKm;
    data['fare'] = fare;
    data['estimated_distance'] = estimatedDistance;
    data['estimated_duration'] = estimatedDuration;
    data['estimated_fare'] = estimatedFare;
    data['request type'] = requestType;
    data['encoded_polyline'] = polyline;
    data['area_id'] = areaId;
    return data;
  }
}

import 'package:ride_sharing_user_app/util/images.dart';

/// Vehicle category types from the backend. Besides car and motor_bike,
/// E-Ride Move adds goods vehicles (tricycle, pickup, dyna, truck); a trip on
/// one of them is a move, with the price agreed with the driver in person.
class VehicleTypeHelper {
  static const List<String> moveTypes = ['tricycle', 'pickup', 'dyna', 'truck'];

  static bool isMove(String? type) => moveTypes.contains(type);

  static bool isBike(String? type) => type == 'motor_bike';

  /// Top-down art for map markers.
  static String topArt(String? type) => isBike(type) ? Images.bikeTop : isMove(type) ? Images.truckTop : Images.carTop;
}

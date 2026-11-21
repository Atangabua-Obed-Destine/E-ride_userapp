import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/helper/vehicle_type_helper.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/nearby_drivers_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/estimated_fare_model.dart';
import 'dart:math' as math;


class MapController extends GetxController implements GetxService {

  Set<Marker>? nearestDeliveryManMarkers;
  bool _isLoading = false;
  Map<PolylineId, Polyline> polylines = {};
  Set<Marker> markers = HashSet<Marker>();
  GoogleMapController? mapController;
  List<LatLng> _polylineCoordinateList = [];
  bool isTrafficEnable = false;

  bool get isLoading => _isLoading;

  @override
  void onInit() {
    initializeData();
    super.onInit();
  }

  void initializeData() {
    markers = {};
    polylines = {};
    _isLoading = false;
  }

  void notifyMapController() {
    update();
  }

  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> showParcelAddressMarker(LatLng position, {required bool isSender}) async {
    markers.removeWhere((marker) =>
        marker.markerId.value == 'parcel_sender' ||
        marker.markerId.value == 'parcel_receiver');

    final Uint8List icon = await convertAssetToUnit8List(
      isSender ? Images.fromIcon : Images.pickLocationIcon,
      width: 30,
    );

    markers.add(Marker(
      markerId: MarkerId(isSender ? 'parcel_sender' : 'parcel_receiver'),
      position: position,
      anchor: const Offset(0.4, 0.8),
      icon: BitmapDescriptor.bytes(icon),
    ));

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: position, zoom: 16)),
    );
    update();
  }

  void clearParcelAddressMarkers() {
    markers.removeWhere((marker) =>
        marker.markerId.value == 'parcel_sender' ||
        marker.markerId.value == 'parcel_receiver');
    update();
  }

  Future<void> getPolyline() async {
    if(Get.find<RideController>().encodedPolyLine.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      List<LatLng> result = decodeEncodedPolyline(Get.find<RideController>().encodedPolyLine);
      if (result.isNotEmpty) {
        for (var point in result) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        _addPolyLine(polylineCoordinates);
        _polylineCoordinateList = polylineCoordinates;

        setFromToMarker(
          LatLng(result[0].latitude, result[0].longitude),
          LatLng(result[result.length-1].latitude, result[result.length-1].longitude),
          latLongList: _polylineCoordinateList
        );
      }
    }
  }

  List<LatLng> decodeEncodedPolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      LatLng p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }

  void _addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      width: 5,
      color: Theme.of(Get.context!).primaryColor,
    );
    polylines[id] = polyline;
    update();
  }

  Future <void> searchDeliveryMen() async {
    final Uint8List carMarkerIcon = await convertAssetToUnit8List(Images.carTop, width: 25);
    final Uint8List bikeMarkerIcon = await convertAssetToUnit8List(Images.bikeTop, width: 25);
    final Uint8List truckMarkerIcon = await convertAssetToUnit8List(Images.truckTop, width: 25);
    nearestDeliveryManMarkers = {};
    for(int i = 0; i < Get.find<RideController>().nearestDriverList.length; i++) {

      MarkerId markerId = MarkerId('rider_$i');
      nearestDeliveryManMarkers!.add(Marker(
        markerId: markerId,
        visible: true,
        draggable: false,
        zIndexInt: 2,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        position: LatLng(double.parse(Get.find<RideController>().nearestDriverList[i].latitude!), double.parse(Get.find<RideController>().nearestDriverList[i].longitude!)),
        icon: BitmapDescriptor.bytes(VehicleTypeHelper.isBike(Get.find<RideController>().nearestDriverList[i].category) ? bikeMarkerIcon
            : VehicleTypeHelper.isMove(Get.find<RideController>().nearestDriverList[i].category) ? truckMarkerIcon : carMarkerIcon),
      ));

    }
    update();
  }

  // ---------------------------------------------------------------------------
  // Live nearby drivers ("Choose a vehicle" and "Finding your driver").
  //
  // Kept in their own marker and circle sets so the route, pickup/destination
  // and on-trip driver markers in [markers] are never mixed in or cleared.
  // ---------------------------------------------------------------------------

  Set<Marker> nearbyDriverMarkers = {};
  Set<Circle> pickupCircles = {};
  final Map<String, _NearbyIcon> _nearbyIconCache = {};
  final Map<String, ui.Image> _vehicleArtCache = {};
  int _nearbyBuild = 0;

  /// Rebuilds the driver markers from NearbyDriversController. The selected
  /// category's drivers are drawn at full strength and the nearest of them
  /// gets a red ring and a "~N min" label; the rest are dimmed. While the
  /// request is out (finding a driver) everyone but the nearest is dimmed.
  Future<void> refreshNearbyDriverMarkers() async {
    final int build = ++_nearbyBuild;
    final NearbyDriversController nearby = Get.find<NearbyDriversController>();
    final RideController ride = Get.find<RideController>();
    final LatLng? pickup = nearby.pickup;

    if (!nearby.isActive || pickup == null) {
      clearNearbyDriverMarkers();
      return;
    }

    final bool finding = ride.currentRideState == RideState.findingRider;
    final FareModel? selected = ride.fareList.isEmpty ? null : ride.selectedType;
    final NearbyDriver? nearest = nearby.nearestFor(selected);

    final Set<Marker> next = {};
    for (int i = 0; i < nearby.drivers.length; i++) {
      final NearbyDriver d = nearby.drivers[i];
      final bool isNearest = identical(d, nearest);
      final bool inCategory = selected == null || nearby.matches(d, selected);
      final _NearbyIcon icon = await _nearbyIcon(
        art: d.artAsset,
        highlighted: isNearest,
        label: isNearest ? d.etaLabel : null,
      );
      if (build != _nearbyBuild) return;

      next.add(Marker(
        markerId: MarkerId('nearby_${d.driver.userId ?? i}'),
        position: d.position,
        icon: icon.descriptor,
        anchor: icon.anchor,
        alpha: isNearest ? 1 : ((finding || !inCategory) ? 0.45 : 1),
        zIndexInt: isNearest ? 1 : 0,
        infoWindow: InfoWindow(
          title: d.isHere ? 'here_now'.tr : '~${d.etaMinutes} ${'min_short'.tr} ${'away'.tr}',
          snippet: '${(d.distanceMeters / 1000).toStringAsFixed(1)} km',
        ),
      ));
    }
    if (build != _nearbyBuild) return;

    final Color accent = Theme.of(Get.context!).primaryColor;
    final double radiusKm = Get.find<ConfigController>().config?.searchRadius ?? 0;
    pickupCircles = {
      if (radiusKm > 0)
        Circle(
          circleId: const CircleId('nearby_search_radius'),
          center: pickup,
          radius: radiusKm * 1000,
          fillColor: accent.withValues(alpha: 0.035),
          strokeColor: accent.withValues(alpha: 0.25),
          strokeWidth: 1,
        ),
      Circle(
        circleId: const CircleId('nearby_pickup_halo'),
        center: pickup,
        radius: 90,
        fillColor: accent.withValues(alpha: 0.14),
        strokeColor: accent.withValues(alpha: 0.4),
        strokeWidth: 1,
      ),
    };
    nearbyDriverMarkers = next;
    update();
  }

  void clearNearbyDriverMarkers() {
    _nearbyBuild++;
    if (nearbyDriverMarkers.isEmpty && pickupCircles.isEmpty) return;
    nearbyDriverMarkers = {};
    pickupCircles = {};
    update();
  }

  /// Frames the pickup and its three nearest drivers.
  void fitPickupAndNearest() {
    final NearbyDriversController nearby = Get.find<NearbyDriversController>();
    final LatLng? pickup = nearby.pickup;
    if (pickup == null || mapController == null) return;
    final List<NearbyDriver> closest = nearby.drivers.take(3).toList();
    // When every driver is right at the pickup the bounds are a few metres
    // wide and would zoom into a single building; keep a street-level view.
    final double span = closest.isEmpty ? 0 : closest.last.distanceMeters;
    if (span < 400) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15.5));
      return;
    }
    final List<LatLng> points = [pickup, ...closest.map((d) => d.position)];
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(boundWithMaximumLatLngPoint(points), 80));
  }

  /// A white disc with a soft shadow and the car/bike art; the highlighted one
  /// has a red ring and a red pill label drawn above it. Drawn once per
  /// combination and cached.
  Future<_NearbyIcon> _nearbyIcon({required String art, required bool highlighted, String? label}) async {
    final String key = '$art|$highlighted|${label ?? ''}';
    final _NearbyIcon? cached = _nearbyIconCache[key];
    if (cached != null) return cached;

    final BuildContext? ctx = Get.context;
    final double dpr = ctx != null ? MediaQuery.devicePixelRatioOf(ctx) : 3.0;
    final Color accent = ctx != null ? Theme.of(ctx).primaryColor : const Color(0xFFE02020);

    const double disc = 34, ring = 3, pad = 6, labelH = 20, gap = 4;
    TextPainter? text;
    if (label != null) {
      text = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final double labelW = text == null ? 0 : text.width + 16;
    final double width = math.max(disc + pad * 2, labelW + pad * 2);
    final double top = text == null ? 0 : labelH + gap;
    final double height = top + disc + pad * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(dpr);

    final Offset center = Offset(width / 2, top + pad + disc / 2);
    canvas.drawCircle(center.translate(0, 1.5), disc / 2,
        Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(center, disc / 2, Paint()..color = Colors.white);
    if (highlighted) {
      canvas.drawCircle(center, disc / 2 - ring / 2,
          Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = ring);
    }

    final ui.Image artImage = await _vehicleArt(art, (20 * dpr).round());
    final double artW = artImage.width / dpr, artH = artImage.height / dpr;
    canvas.drawImageRect(
      artImage,
      Rect.fromLTWH(0, 0, artImage.width.toDouble(), artImage.height.toDouble()),
      Rect.fromCenter(center: center, width: artW, height: artH),
      Paint()..filterQuality = FilterQuality.medium,
    );

    if (text != null) {
      final RRect pill = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(width / 2, labelH / 2), width: labelW, height: labelH),
        const Radius.circular(labelH / 2),
      );
      canvas.drawRRect(pill, Paint()..color = accent);
      text.paint(canvas, Offset(width / 2 - text.width / 2, labelH / 2 - text.height / 2));
    }

    final ui.Image image = await recorder.endRecording().toImage((width * dpr).ceil(), (height * dpr).ceil());
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final _NearbyIcon icon = _NearbyIcon(
      BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr),
      Offset(0.5, center.dy / height),
    );
    _nearbyIconCache[key] = icon;
    return icon;
  }

  Future<ui.Image> _vehicleArt(String asset, int targetWidth) async {
    final ui.Image? cached = _vehicleArtCache[asset];
    if (cached != null) return cached;
    final ByteData data = await rootBundle.load(asset);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: targetWidth);
    final ui.Image image = (await codec.getNextFrame()).image;
    _vehicleArtCache[asset] = image;
    return image;
  }

  double sheetHeight = 0;
  void setContainerHeight(double height , bool notify){
    sheetHeight = height;
    if(notify){
      update();
    }

  }

  void setFromToMarker(LatLng from, LatLng to,{bool isBound = true, required List<LatLng>latLongList}) async{
    markers = HashSet();
    List<LatLng> intermediateCoordinates = [];
    int markerId = 0;
    Uint8List fromMarker = await convertAssetToUnit8List(Images.fromIcon, width: 30);
    Uint8List toMarker = await convertAssetToUnit8List(Images.pickLocationIcon, width: 30);
    Uint8List intermediateIcon = await convertAssetToUnit8List(Images.ongoingMarkerIcon, width: 30);

    markers.add(Marker(
      markerId: const MarkerId('from'),
      position: from,
      anchor: const Offset(0.4, 0.7),
      infoWindow:  InfoWindow(
        title:  Get.find<RideController>().tripDetails?.pickupAddress ?? '',
        snippet: 'pick_up_location'.tr,
      ),
      icon:  BitmapDescriptor.bytes(fromMarker),
    ));

    markers.add(Marker(
      markerId: const MarkerId('to'),
      position: to,
      anchor: const Offset(0.4, 0.8),
      infoWindow:  InfoWindow(
        title:  Get.find<RideController>().tripDetails?.destinationAddress ?? '',
        snippet: 'destination'.tr,
      ),
      icon:  BitmapDescriptor.bytes(toMarker),
    ));

     if(Get.find<RideController>().currentTripDetails?.intermediateCoordinates != null){
       List<dynamic> parsedList = jsonDecode(Get.find<RideController>().currentTripDetails!.intermediateCoordinates!);

       parsedList.map((item){
         intermediateCoordinates.add(LatLng(item[0], item[1]));
       }).toList();

     }else {
       if(Get.find<LocationController>().extraOneRoute){
         intermediateCoordinates.add(LatLng(Get.find<LocationController>().extraRouteAddress?.latitude ?? 0, Get.find<LocationController>().extraRouteAddress?.longitude ?? 0));
       }
       if(Get.find<LocationController>().extraTwoRoute){
         intermediateCoordinates.add(LatLng(Get.find<LocationController>().extraRouteTwoAddress?.latitude ?? 0, Get.find<LocationController>().extraRouteTwoAddress?.longitude ?? 0));
       }

     }


    for (var coordinates in intermediateCoordinates) {
      markers.add(Marker(
        markerId: MarkerId((markerId++).toString()),
        position: coordinates,
        anchor: const Offset(0.4, 0.8),
        icon:  BitmapDescriptor.bytes(intermediateIcon),
      ));
    }


    if(isBound){
      try {
        LatLngBounds? bounds;
        if(mapController != null) {
          bounds = boundWithMaximumLatLngPoint(latLongList);
        }
        LatLng centerBounds = LatLng(
          (bounds!.northeast.latitude + bounds.southwest.latitude)/2,
          (bounds.northeast.longitude + bounds.southwest.longitude)/2,
        );
        mapController!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: centerBounds, zoom: 16,
        )));
        zoomToFit(mapController, bounds, centerBounds, padding: 0.5);
      }catch(e) {
        // debugPrint('jhkygutyv' + e.toString());
      }
    }

    update();
  }

  void updateMarkerAndCircle({LatLng? latLng}) async {
    Uint8List car = await convertAssetToUnit8List( Images.mapLocationIcon, width: 100);
    // Removed once the new icon is ready, so the marker does not blink.
    markers.removeWhere((marker) => marker.markerId.value == "my_location");

    if(Get.find<RideController>().tripDetails != null && _polylineCoordinateList.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('my_location'),
        position: latLng ?? _polylineCoordinateList.first,
        rotation: _calculateBearing(
          _polylineCoordinateList.first,
          _polylineCoordinateList.length > 1 ?  _polylineCoordinateList[1] : _polylineCoordinateList.last,
        ),
        draggable: false,
        zIndexInt: 2,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        icon: BitmapDescriptor.bytes(car),
      ));
      update();
    }
  }

  double _calculateBearing(LatLng startPoint, LatLng endPoint) {
    final double startLat = _toRadians(startPoint.latitude);
    final double startLng = _toRadians(startPoint.longitude);
    final double endLat = _toRadians(endPoint.latitude);
    final double endLng = _toRadians(endPoint.longitude);

    final double deltaLng = endLng - startLng;

    final double y = math.sin(deltaLng) * math.cos(endLat);
    final double x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(deltaLng);

    final double bearing = math.atan2(y, x);

    return (_toDegrees(bearing) + 360) % 360;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  double _toDegrees(double radians) => radians * (180.0 / math.pi);

  // Decoded marker icons. The car and location markers are redrawn on every GPS
  // fix and driver update; decoding the PNG each time was wasted work.
  static final Map<String, Uint8List> _iconCache = {};

  Future<Uint8List> convertAssetToUnit8List(String imagePath, {int width = 50}) async {
    final String key = '$imagePath@$width';
    final Uint8List? cached = _iconCache[key];
    if (cached != null) return cached;
    ByteData data = await rootBundle.load(imagePath);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return _iconCache[key] = (await fi.image.toByteData(format:ui. ImageByteFormat.png))!.buffer.asUint8List();
  }

  // The camera stays north-up: the map has no compass, and turning it to follow the
  // route showed south at the top, with roads pointing the wrong way for the customer.
  Future<void> zoomToFit(GoogleMapController? controller, LatLngBounds? bounds, LatLng centerBounds, {double padding = 0.5}) async {
    bool keepZoomingOut = true;
    while(keepZoomingOut) {

      final LatLngBounds screenBounds = await controller!.getVisibleRegion();
      if(fits(bounds!, screenBounds)) {
        keepZoomingOut = false;
        final double zoomLevel = await controller.getZoomLevel() - padding;
        controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: centerBounds,
          zoom: zoomLevel,
        )));
        break;
      }
      else {
        // Zooming out by 0.1 zoom level per iteration
        final double zoomLevel = await controller.getZoomLevel() - 0.1;
        controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: centerBounds,
          zoom: zoomLevel,
        )));
      }
    }
  }

  bool fits(LatLngBounds fitBounds, LatLngBounds screenBounds) {
    final bool northEastLatitudeCheck = screenBounds.northeast.latitude >= fitBounds.northeast.latitude;
    final bool northEastLongitudeCheck = screenBounds.northeast.longitude >= fitBounds.northeast.longitude;

    final bool southWestLatitudeCheck = screenBounds.southwest.latitude <= fitBounds.southwest.latitude;
    final bool southWestLongitudeCheck = screenBounds.southwest.longitude <= fitBounds.southwest.longitude;

    return northEastLatitudeCheck && northEastLongitudeCheck && southWestLatitudeCheck && southWestLongitudeCheck;
  }

  void setOwnCurrentLocation(LatLng? latLng) async{
    markers.removeWhere((marker) => marker.markerId.value == "my_location");

    Uint8List myIcon = await convertAssetToUnit8List(Images.mapLocationIcon, width: 100);

    //LatLng? latlng = await Get.find<LocationController>().getCurrentPosition();

    if(latLng != null){
      markers.add( Marker(
          markerId: const MarkerId("my_location"),
          position: latLng,
          draggable: false,
          zIndexInt: 2,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: BitmapDescriptor.bytes(myIcon)));

      if(mapController != null){
        mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
            target: latLng,
            tilt: 0,
            zoom: 16
        )));
      }
    }
    update();
  }


  Future<void> getDriverToPickupOrDestinationPolyline(String lines,{bool mapBound = false}) async {
    if(lines.isNotEmpty) {
      List<LatLng> polylineCoordinates = [];
      List<LatLng> result = decodeEncodedPolyline(lines);
      if (result.isNotEmpty) {
        for (var point in result) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        isInsideCircle(result[0].latitude, result[0].longitude, result[result.length-1].latitude, result[result.length-1].longitude, Get.find<ConfigController>().config!.completionRadius!);
        _addPolyLine(polylineCoordinates);
        _polylineCoordinateList = polylineCoordinates;
        updateDriverMarker(_polylineCoordinateList);


        if(mapBound){
          boundMapScreen(LatLng(result[0].latitude, result[0].longitude), LatLng(result[result.length-1].latitude, result[result.length-1].longitude));
        }
      }
    }
  }

  void updateDriverMarker(List<LatLng> latLngList) async{
    final String? vehicleType = Get.find<RideController>().tripDetails!.vehicleCategory!.type;
    Uint8List car = await convertAssetToUnit8List(VehicleTypeHelper.isBike(vehicleType) ? Images.bike
        : VehicleTypeHelper.isMove(vehicleType) ? Images.truckTop : Images.carTop, width: 25);
    markers.removeWhere((marker) => marker.markerId.value == "driverPosition");


    if(Get.find<RideController>().tripDetails != null && latLngList.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('driverPosition'),
        position: latLngList.first,
        rotation: _calculateBearing(
          latLngList.first,
          latLngList.length > 1 ?  latLngList[1] : latLngList.last,
        ),
        draggable: false,
        zIndexInt: 2,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        icon: BitmapDescriptor.bytes(car),
      ));
      update();
    }

  }

  bool _isInside = false;
  bool get isInside => _isInside;

  double distanceBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    double distance = Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
    return distance; // Distance in meters
  }

  void isInsideCircle(double lat, double lng, double latCenter, double lngCenter, double radius) {
    // Calculate the distance between two points using Haversine formula
    double distance = distanceBetween(lat, lng, latCenter, lngCenter);
    // Check if the distance is less than or equal to the radius
    _isInside = (distance <= radius) ? true : false;
  }


  void setMarkersInitialPosition(){
    if(Get.find<RideController>().encodedPolyLine.isNotEmpty) {
      List<LatLng> markers = decodeEncodedPolyline(Get.find<RideController>().encodedPolyLine);
      setFromToMarker(
          LatLng(markers[0].latitude, markers[0].longitude),
          LatLng(markers[markers.length-1].latitude, markers[markers.length-1].longitude),
          isBound: false,latLongList: markers
      );
    }
  }

  void boundMapScreen(LatLng startingPoint , LatLng endingPoint){
    try {
      LatLngBounds? bounds;
      if(mapController != null) {
        bounds = boundWithMaximumLatLngPoint([startingPoint, endingPoint]);
      }
      LatLng centerBounds = LatLng(
        (bounds!.northeast.latitude + bounds.southwest.latitude)/2,
        (bounds.northeast.longitude + bounds.southwest.longitude)/2,
      );
      mapController!.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: centerBounds, zoom: 16,
      )));
      zoomToFit(mapController, bounds, centerBounds, padding: 0.5);
    }catch(e) {
      // debugPrint('jhkygutyv' + e.toString());
    }
  }


  LatLngBounds boundWithMaximumLatLngPoint(List<LatLng> list) {
    assert(list.isNotEmpty);
    var firstLatLng = list.first;
    var s = firstLatLng.latitude,
        n = firstLatLng.latitude,
        w = firstLatLng.longitude,
        e = firstLatLng.longitude;
    for (var i = 1; i < list.length; i++) {
      var latlng = list[i];
      s = min(s, latlng.latitude);
      n = max(n, latlng.latitude);
      w = min(w, latlng.longitude);
      e = max(e, latlng.longitude);
    }
    return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
  }

  void toggleTrafficView(){
    isTrafficEnable = !isTrafficEnable;
    update();
  }

}

class _NearbyIcon {
  final BitmapDescriptor descriptor;
  final Offset anchor;
  const _NearbyIcon(this.descriptor, this.anchor);
}

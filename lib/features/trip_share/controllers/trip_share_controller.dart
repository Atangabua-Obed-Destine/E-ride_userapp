import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/move/controllers/move_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/ride/domain/models/trip_details_model.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/models/trusted_contact_model.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/services/trip_share_service_interface.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/phone_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Share trip: a live link friends, family or a parcel's receiver open in any
/// browser, from the driver's acceptance until the trip ends. Trusted contacts
/// get it in one tap on WhatsApp; nothing is ever sent automatically.
class TripShareController extends GetxController implements GetxService {
  final TripShareServiceInterface tripShareServiceInterface;
  TripShareController({required this.tripShareServiceInterface});

  static const int maxContacts = 3;
  static const List<String> liveStatuses = [AppConstants.accepted, AppConstants.outForPickup, AppConstants.ongoing, AppConstants.returning];

  List<TrustedContact>? contacts;
  bool savingContact = false;

  String? _tripId;
  String? url;
  String? receiverName;
  String? receiverPhone;
  bool loadingLink = false;
  /// The customer sent the link to someone during this trip.
  bool shared = false;
  bool stopping = false;

  static bool canShare(TripDetails? trip) {
    return trip?.id != null &&
        (Get.find<ConfigController>().config?.isRealTimeLocationShareEnable ?? false) &&
        liveStatuses.contains(trip!.currentStatus);
  }

  bool isParcel(TripDetails trip) => trip.type == AppConstants.parcel;

  void _forTrip(String tripId) {
    if (_tripId == tripId) return;
    _tripId = tripId;
    url = null;
    receiverName = null;
    receiverPhone = null;
    shared = false;
  }

  /// The trip's live link, fetched once per trip.
  Future<String?> _link(TripDetails trip) async {
    _forTrip(trip.id!);
    if (url != null) return url;
    loadingLink = true;
    update();
    final Response response = await tripShareServiceInterface.getShareLink(trip.id!);
    loadingLink = false;
    if (response.statusCode == 200 && response.body['data'] is Map) {
      final Map data = response.body['data'];
      url = data['url']?.toString();
      if (data['receiver'] is Map) {
        receiverName = data['receiver']['name']?.toString();
        receiverPhone = data['receiver']['phone']?.toString();
      }
    } else {
      showCustomSnackBar(MoveController.firstError(response));
    }
    update();
    return url;
  }

  /// Loads the parcel receiver's details for the card, without sharing yet.
  Future<void> prepare(TripDetails trip) async {
    if (isParcel(trip) && (_tripId != trip.id || url == null) && !loadingLink) {
      await _link(trip);
    } else {
      _forTrip(trip.id!);
    }
  }

  String _message(TripDetails trip, String link) {
    final String name = Get.find<ProfileController>().customerFirstName();
    if (isParcel(trip)) {
      return 'trip_share_message_parcel'.trParams({'receiver': receiverName ?? '', 'name': name, 'link': link});
    }
    return (trip.isMove ? 'trip_share_message_move' : 'trip_share_message').trParams({'name': name, 'link': link});
  }

  /// WhatsApp with the message ready; an SMS when WhatsApp cannot be opened.
  Future<void> shareTo(TripDetails trip, String phone) async {
    final String? link = await _link(trip);
    if (link == null) return;
    final String text = _message(trip, link);
    final String digits = PhoneHelper.waDigits(phone);
    bool opened = false;
    try {
      opened = await launchUrl(Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      try {
        opened = await launchUrl(Uri(scheme: 'sms', path: phone, queryParameters: {'body': text}));
      } catch (_) {}
    }
    if (opened) {
      shared = true;
      update();
    } else {
      showCustomSnackBar('could_not_open_link'.tr);
    }
  }

  Future<void> shareOther(TripDetails trip) async {
    final String? link = await _link(trip);
    if (link == null) return;
    await SharePlus.instance.share(ShareParams(text: _message(trip, link)));
    shared = true;
    update();
  }

  Future<void> copyLink(TripDetails trip) async {
    final String? link = await _link(trip);
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    shared = true;
    update();
    showCustomSnackBar('link_copied'.tr, isError: false);
  }

  /// Links already sent stop working.
  Future<void> stopSharing(TripDetails trip) async {
    stopping = true;
    update();
    final Response response = await tripShareServiceInterface.stopSharing(trip.id!);
    stopping = false;
    if (response.statusCode == 200) {
      url = response.body['data'] is Map ? response.body['data']['url']?.toString() : null;
      shared = false;
      showCustomSnackBar('trip_share_stopped'.tr, isError: false);
    } else {
      showCustomSnackBar(MoveController.firstError(response));
    }
    update();
  }

  // ---- Trusted contacts

  Future<void> getContacts({bool force = false}) async {
    if (contacts != null && !force) return;
    final Response response = await tripShareServiceInterface.getContacts();
    _setContacts(response);
    contacts ??= [];
    update();
  }

  Future<bool> saveContact({String? id, required String name, required String phone}) async {
    savingContact = true;
    update();
    final Response response = id == null
        ? await tripShareServiceInterface.addContact(name, phone)
        : await tripShareServiceInterface.updateContact(id, name, phone);
    savingContact = false;
    final bool ok = _setContacts(response);
    if (!ok) showCustomSnackBar(MoveController.firstError(response));
    update();
    return ok;
  }

  Future<void> deleteContact(TrustedContact contact) async {
    final Response response = await tripShareServiceInterface.deleteContact(contact.id);
    if (!_setContacts(response)) showCustomSnackBar(MoveController.firstError(response));
    update();
  }

  /// A contacts list returned by another call (night sharing); true if it was one.
  bool applyContacts(Response response) {
    final bool ok = _setContacts(response);
    if (ok) update();
    return ok;
  }

  bool _setContacts(Response response) {
    if (response.statusCode == 200 && response.body['data'] is List) {
      contacts = [
        for (final item in response.body['data'] as List)
          if (item is Map<String, dynamic>) TrustedContact.fromJson(item),
      ];
      return true;
    }
    return false;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/features/splash/domain/models/config_model.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/splash/domain/services/config_service_interface.dart';

class ConfigController extends GetxController implements GetxService {
  final ConfigServiceInterface configServiceInterface;
  ConfigController({required this.configServiceInterface});

  ConfigModel? _config;

  ConfigModel? get config => _config;

  /// Dial code for the configured country, falling back to Cameroon.
  ///
  /// The /configuration call can fail or still be in flight when an auth screen
  /// builds. Those screens used to read
  /// `config!.countryCode!` ... `.dialCode!` directly, so a null config threw
  /// during build and painted the red error screen instead of the login form.
  /// CountryCode.fromCountryCode also throws on a code it does not know, hence
  /// the try/catch.
  String get countryDialCode {
    final String? code = _config?.countryCode;
    if(code != null && code.isNotEmpty) {
      try {
        final String? dial = CountryCode.fromCountryCode(code).dialCode;
        if(dial != null && dial.isNotEmpty) {
          return dial;
        }
      } catch (_) {
        // unknown country code in the config; fall through to the default
      }
    }
    return '+237';
  }

  /// OTP resend countdown, falling back to 60s when there is no config yet.
  int get otpResendTime => _config?.otpResendTime ?? 60;

  /// True only when the backend has the CUSTOMER app in maintenance mode.
  ///
  /// Reads false when there is no config, so a failed /configuration call
  /// cannot crash the maintenance checks that run on the cold-start path and
  /// on every notification.
  bool get isUnderMaintenance {
    final MaintenanceMode? mode = _config?.maintenanceMode;
    return mode != null &&
        mode.maintenanceStatus == 1 &&
        mode.selectedMaintenanceSystem?.userApp == 1;
  }


  bool isShowToolTips = true;
  bool loading = false;

  /// The fresh configuration, while it loads behind a saved one.
  Future<bool>? refreshing;

  /// The configuration saved the last time it loaded, so the app can open
  /// without waiting on the network. False when there is none (first launch).
  bool loadSavedConfig() {
    final String? saved = Get.find<SharedPreferences>().getString(AppConstants.savedConfig);
    if (saved == null) return false;
    try {
      _config = ConfigModel.fromJson(jsonDecode(saved));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> getConfigData({bool reload= false}) async {
    bool isSuccess = false;
    loading = true;
    if(loading){
      update();
    }
    Response response = await configServiceInterface.getConfigData();
    if(response.statusCode == 200) {
      loading = false;
      isSuccess = true;
      _config = ConfigModel.fromJson(response.body);
      Get.find<SharedPreferences>().setString(AppConstants.savedConfig, jsonEncode(response.body));
    }else {loading = false;
      ApiChecker.checkApi(response);
    }
    update();
    return isSuccess;

  }

  Future<bool> initSharedData() {
    return configServiceInterface.initSharedData();
  }

  Future<bool> removeSharedData() {
    return configServiceInterface.removeSharedData();
  }

  bool showIntro() {
    return configServiceInterface.showIntro()!;

  }
  void disableIntro() {
    configServiceInterface.disableIntro();
  }


  String? _pusherConnectionStatus;
  String? get pusherConnectionStatus => _pusherConnectionStatus;

  void setPusherStatus(String? connection){
    _pusherConnectionStatus = connection;
  }

  bool haveOngoingRides() {
    return configServiceInterface.haveOngoingRides();
  }

  void saveOngoingRides(bool value) {
    return configServiceInterface.saveOngoingRides(value);
  }

  void hideToolTips(){
    isShowToolTips = false;
  }

}
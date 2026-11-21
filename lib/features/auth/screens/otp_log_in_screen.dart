import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/auth_scaffold.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/features/auth/screens/verification_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_text_field.dart';

class OtpLoginScreen extends StatefulWidget {
  final VerificationForm from;
  const OtpLoginScreen({super.key, required this.from});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  TextEditingController phoneController = TextEditingController();
  FocusNode phoneNode = FocusNode();
  @override
  void initState() {
    super.initState();

    Get.find<AuthController>().countryDialCode = Get.find<ConfigController>().countryDialCode;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(builder: (authController){
      return AuthScaffold(
        title: 'login_with_otp'.tr,
        subtitle: 'please_enter_your_mobile_number_to_login'.tr,
        onBack: () => Navigator.canPop(context) ? Get.back() : Get.offAll(()=> const SignInScreen()),
        child: Column(children: [
          CustomTextField(
            isCodePicker: true,
            hintText: 'phone'.tr,
            inputType: TextInputType.number,
            countryDialCode: authController.countryDialCode,
            controller: phoneController,
            focusNode: phoneNode,
            inputAction: TextInputAction.done,
            onCountryChanged: (CountryCode countryCode){
              authController.countryDialCode = countryCode.dialCode!;
              authController.setCountryCode(countryCode.dialCode!);
            },
            autoFocus: phoneController.text.isEmpty,
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          authController.isOtpSending ?
          Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0)) :
          ButtonWidget(
            buttonText: 'get_otp'.tr,
            height: 52,
            radius: 16,
            onPressed: () {
              String phone = phoneController.text.trim();

              if(phone.isEmpty) {
                showCustomSnackBar('enter_your_phone_number'.tr);
                FocusScope.of(context).requestFocus(phoneNode);
              }else if(!GetUtils.isPhoneNumber(authController.countryDialCode + phone)) {
                showCustomSnackBar('phone_number_is_not_valid'.tr);
              }else {
                authController.checkOAuth(countryCode: authController.countryDialCode, number: phone).then((value){
                  if(value.statusCode == 200){
                    if(Get.find<ConfigController>().config?.isFirebaseOtpVerification ?? false){
                      authController.firebaseOtpSend(authController.countryDialCode + phone, from: widget.from);
                    }else if(Get.find<ConfigController>().config?.isSmsGateway ?? false){
                      authController.sendOtp(authController.countryDialCode + phone).then((value) {
                        if(value.statusCode == 200) {
                          Get.to(() =>  VerificationScreen(
                            number: authController.countryDialCode + phone,
                            form: widget.from,
                          ));
                        }
                      });
                    }else{
                      showCustomSnackBar('sms_gateway_not_integrate'.tr);
                    }
                  }
                });
              }
            },
          ),
        ]),
      );
    });
  }
}

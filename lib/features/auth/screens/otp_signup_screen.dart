import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/sign_up_body.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/social_log_in_body.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/additional_field_widget.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/test_field_title.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_text_field.dart';

class OtpSignupScreen extends StatefulWidget {
  final String? phoneNumber;
  final SocialLogInBody? socialLogInBody;
  final bool fromOtpRegistration;
  const OtpSignupScreen({super.key, required this.phoneNumber, required this.fromOtpRegistration, this.socialLogInBody});

  @override
  State<OtpSignupScreen> createState() => _OtpSignUpScreenState();
}

class _OtpSignUpScreenState extends State<OtpSignupScreen> {

  final TextEditingController fNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController referralCodeController = TextEditingController();

  final FocusNode fNameNode = FocusNode();
  final FocusNode referralNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if(widget.socialLogInBody?.userName != null){
      fNameController.text = widget.socialLogInBody?.userName ?? '';
    }
    Get.find<AuthController>().loadAdditionalFields(true);
  }

  @override
  void dispose() {
    fNameController.dispose();
    phoneController.dispose();
    referralCodeController.dispose();
    fNameNode.dispose();
    referralNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        body: GetBuilder<AuthController>(builder: (authController) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: Dimensions.paddingSizeSignUp),
      
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.canPop(context) ? Get.back() : Get.offAll(()=> const SignInScreen()),
            ),
      
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              child: Text(
                'setup_profile'.tr,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeTwenty),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              child: Text(
                'Just one step away! This will help make your profile more personalized.'.tr,
                style: textMedium.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: Dimensions.fontSizeSmall,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      
            Flexible(child: Container(
              decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Dimensions.paddingSizeDefault)
                ),
              padding: EdgeInsets.all(Dimensions.paddingSizeDefault).copyWith(top: 0),
              margin: EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextFieldTitle(title: 'name'.tr, isRequired: true),
                    CustomTextField(
                      capitalization: TextCapitalization.words,
                      hintText: 'enter_your_name'.tr,
                      inputType: TextInputType.name,
                      prefixIcon: Images.person,
                      controller: fNameController,
                      focusNode: fNameNode,
                      nextFocus: referralNode,
                      inputAction: TextInputAction.next,
                      autoFocus: fNameController.text.isEmpty,
                    ),

                    if (Get.find<ConfigController>().config?.referralEarningStatus ?? false) ...[
                      TextFieldTitle(title: 'refer_code'.tr),
                      CustomTextField(
                        hintText: 'refer_code'.tr,
                        inputType: TextInputType.text,
                        controller: referralCodeController,
                        focusNode: referralNode,
                        inputAction: TextInputAction.done,
                        prefixIcon: Images.referIcon,
                      ),
                    ],

                    if(!widget.fromOtpRegistration)...[
                      TextFieldTitle(title: 'phone'.tr, isRequired: true),
                      CustomTextField(
                        isCodePicker: true,
                        hintText: 'phone'.tr,
                        inputType: TextInputType.phone,
                        countryDialCode: authController.countryDialCode,
                        controller: phoneController,
                        inputAction: TextInputAction.next,
                        onCountryChanged: (CountryCode countryCode) {
                          authController.countryDialCode = countryCode.dialCode!;
                          authController.setCountryCode(countryCode.dialCode!);
                        },
                        autoFocus: phoneController.text.isEmpty,
                      ),
                    ],

                    if (authController.additionalFields.isNotEmpty)...[
                      const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                      Text("additional_info".tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),

                      ...List.generate(
                        authController.additionalFields.length,
                            (index) => AdditionalFieldWidget(
                          fieldModel: authController.additionalFields[index],
                          index: index,
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeLarge),
                    ],
                  ]),
              ),
            ))
          ]);
        }),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(
              color: Theme.of(context).hintColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )],
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(Dimensions.radiusExtraLarge),
              topLeft: Radius.circular(Dimensions.radiusExtraLarge),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: Dimensions.paddingSizeSmall),
      
            GetBuilder<AuthController>(builder: (authController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                child: authController.isLoading
                    ? Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0))
                    : ButtonWidget(
                  buttonText: 'done'.tr,
                  radius: 50,
                  onPressed: () {
                    final String fName = fNameController.text.trim();
      
                    if (fName.isEmpty) {
                      showCustomSnackBar('first_name_is_required'.tr);
                      FocusScope.of(context).requestFocus(fNameNode);
                    } else if(widget.fromOtpRegistration) {
                      authController.registrationFromOtp(
                          SignUpBody(
                              phone: widget.phoneNumber,
                              fName: fName,
                              referralCode: referralCodeController.text.trim()
                          ), updateFromRegistration: false
                      );
                    }else{
                      if(phoneController.text.trim().isEmpty){
                        showCustomSnackBar('phone_is_required'.tr);
                        FocusScope.of(context).requestFocus(fNameNode);
                      }else{
                        authController.registrationFromSocialLogin(
                            SignUpBody(
                                phone: authController.countryDialCode + phoneController.text.trim(),
                                fName: fName,
                                email: widget.socialLogInBody?.email,
                                referralCode: referralCodeController.text.trim(),
                                loginMedium: widget.socialLogInBody?.medium
                            )
                        );
                      }
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: Dimensions.paddingSizeDefault),
          ]),
        ),
      ),
    );
  }
}
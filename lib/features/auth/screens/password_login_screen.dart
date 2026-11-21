import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_text_field.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/screens/forgot_password_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/auth_scaffold.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class PasswordLoginScreen extends StatefulWidget {
  const PasswordLoginScreen({super.key});

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  TextEditingController passwordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  FocusNode phoneNode = FocusNode();
  FocusNode passwordNode = FocusNode();


  @override
  void initState() {

    if(Get.find<AuthController>().getUserNumber(false).isNotEmpty) {
      phoneController.text =  Get.find<AuthController>().getUserNumber(false);
    }
    passwordController.text = Get.find<AuthController>().getUserPassword(false);

    if(passwordController.text.isNotEmpty) {
      Get.find<AuthController>().setRememberMe();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(builder: (authController){
      return AuthScaffold(
        title: 'login_with_password'.tr,
        subtitle: 'enter_your_mobile_and_Password'.tr,
        onBack: () => Navigator.canPop(context) ? Get.back() : Get.offAll(()=> const SignInScreen()),
        child: Column(children: [
          CustomTextField(
            isCodePicker: true,
            hintText: 'phone'.tr,
            inputType: TextInputType.phone,
            countryDialCode: authController.countryDialCode,
            controller: phoneController,
            focusNode: phoneNode,
            nextFocus: passwordNode,
            inputAction: TextInputAction.next,
            onCountryChanged: (CountryCode countryCode) {
              authController.countryDialCode = countryCode.dialCode!;
              authController.setCountryCode(countryCode.dialCode!);
              FocusScope.of(context).requestFocus(phoneNode);
            },
            autoFocus: phoneController.text.isEmpty,
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          CustomTextField(
            hintText: 'enter_password'.tr,
            inputType: TextInputType.text,
            prefixIcon: Images.lock,
            inputAction: TextInputAction.done,
            isPassword: true,
            controller: passwordController,
            focusNode: passwordNode,
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),

          Row(children: [
            InkWell(
              onTap: () => authController.toggleRememberMe(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                child: Row(children: [
                  SizedBox(width: 20.0, child: Checkbox(
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    activeColor: Theme.of(context).primaryColor,
                    value: authController.isActiveRememberMe,
                    side: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
                    onChanged: (bool? isChecked) => authController.toggleRememberMe(),
                  )),
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  Text('remember_me'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
                ]),
              ),
            ),

            const Spacer(),

            TextButton(
              onPressed: () {
                Get.to(() => const ForgotPasswordScreen(from: VerificationForm.resetPassword));
              },
              child: Text('forgot_password'.tr, style: textSemiBold.copyWith(
                fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor,
              )),
            ),
          ]),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          authController.isLoading ?
          Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0)) :
          ButtonWidget(
            buttonText: 'log_in'.tr,
            height: 52,
            radius: 16,
            onPressed: () {
              String phone = phoneController.text.trim();
              String password = passwordController.text.trim();

              if(phone.isEmpty){
                showCustomSnackBar('phone_number_is_required'.tr);
                FocusScope.of(context).requestFocus(phoneNode);
              }else if(!GetUtils.isPhoneNumber(authController.countryDialCode + phone)) {
                showCustomSnackBar('phone_number_is_not_valid'.tr);
                FocusScope.of(context).requestFocus(phoneNode);
              }else if(password.isEmpty) {
                showCustomSnackBar('password_is_required'.tr);
                FocusScope.of(context).requestFocus(passwordNode);
              }else if(password.length < 8) {
                showCustomSnackBar('minimum_password_length_is_8'.tr);
              }else {
                authController.login(authController.countryDialCode, phone, password);
              }
            },
          ),
        ]),
      );
    });
  }
}

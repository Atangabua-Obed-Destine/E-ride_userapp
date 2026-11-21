import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/social_log_in_body.dart';
import 'package:ride_sharing_user_app/features/auth/screens/otp_log_in_screen.dart';
import 'package:ride_sharing_user_app/features/auth/screens/password_login_screen.dart';
import 'package:ride_sharing_user_app/features/dashboard/controllers/bottom_menu_controller.dart';
import 'package:ride_sharing_user_app/features/settings/domain/html_enum_types.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/screens/sign_up_screen.dart';
import 'package:ride_sharing_user_app/features/settings/screens/policy_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The welcome screen: the splash canvas with the finished route, the
/// E-Ride lockup, and a white card with whichever login methods the admin
/// has enabled. Which methods show, and what each does, is unchanged.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {

  @override
  void initState() {
    super.initState();

    if(Get.find<AuthController>().getLoginCountryCode(false).isNotEmpty) {
      Get.find<AuthController>().countryDialCode = Get.find<AuthController>().getLoginCountryCode(false);
    }else{
      Get.find<AuthController>().countryDialCode = Get.find<ConfigController>().countryDialCode;

    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final options = Get.find<ConfigController>().config?.customerLoginOptions;
    final bool manual = options?.manualLogin ?? false;
    final bool otp = options?.otpLogin ?? false;
    final bool social = options?.socialMediaLogin ?? false;
    final bool apple = (options?.socialLogin?.apple ?? false) && GetPlatform.isIOS;
    final bool google = options?.socialLogin?.google ?? false;
    final bool facebook = options?.socialLogin?.facebook ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (res, val) async {
        Get.find<BottomMenuController>().exitApp();
        return;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: kSplashInk,
          body: GetBuilder<AuthController>(builder: (authController) {
            return Stack(children: [
              Positioned.fill(child: SplashBackdrop(accent: accent)),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.55,
                    child: CustomPaint(
                      painter: RouteMapPainter(animation: const AlwaysStoppedAnimation<double>(1.0), accent: accent),
                    ),
                  ),
                ),
              ),

              Column(children: [
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Image.asset(Images.logoOnDark, height: 72, fit: BoxFit.contain),
                          const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                          Text(
                            'ready_to_ride'.tr,
                            textAlign: TextAlign.center,
                            style: textBold.copyWith(fontSize: 26, color: Colors.white),
                          ),
                          const SizedBox(height: Dimensions.paddingSizeSmall),

                          Text(
                            'log_in_message'.tr,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: textRegular.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Dimensions.paddingSizeLarge, Dimensions.paddingSizeExtraLarge, Dimensions.paddingSizeLarge, Dimensions.paddingSizeDefault,
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if(manual)
                          ButtonWidget(
                            buttonText: 'password_login'.tr,
                            icon: Icons.lock_outline_rounded,
                            height: 52,
                            radius: 16,
                            onPressed: () => Get.to(() => const PasswordLoginScreen()),
                          ),

                        if(otp) ...[
                          if(manual) const SizedBox(height: Dimensions.paddingSizeSmall),
                          ButtonWidget(
                            buttonText: 'otp_login'.tr,
                            icon: Icons.sms_outlined,
                            height: 52,
                            radius: 16,
                            backgroundColor: Theme.of(context).hintColor.withValues(alpha: 0.12),
                            textColor: Theme.of(context).textTheme.bodyLarge?.color,
                            onPressed: () => Get.to(() => const OtpLoginScreen(from: VerificationForm.login)),
                          ),
                        ],

                        if(social && (apple || google || facebook)) ...[
                          if(manual || otp)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
                              child: Row(children: [
                                Expanded(child: Divider(color: Theme.of(context).hintColor.withValues(alpha: 0.25))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                                  child: Text(
                                    'or_sign_in_with'.tr,
                                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
                                  ),
                                ),
                                Expanded(child: Divider(color: Theme.of(context).hintColor.withValues(alpha: 0.25))),
                              ]),
                            ),

                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            if(google) _SocialButton(image: Images.googleLogo, label: 'google'.tr, onTap: () => _onTap(socialLoginType: SocialLoginType.google)),
                            if(facebook) _SocialButton(image: Images.facebookLogo, label: 'facebook'.tr, onTap: () => _onTap(socialLoginType: SocialLoginType.facebook)),
                            if(apple) _SocialButton(image: Images.appleLogo, label: 'apple'.tr, onTap: () => _onTap(socialLoginType: SocialLoginType.apple)),
                          ]),
                        ],
                        const SizedBox(height: Dimensions.paddingSizeLarge),

                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${'do_not_have_an_account'.tr} ',
                            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor),
                          ),
                          TextButton(
                            onPressed: () => Get.to(() => const SignUpScreen()),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('sign_up'.tr, style: textSemiBold.copyWith(color: accent, fontSize: Dimensions.fontSizeSmall)),
                          ),
                        ]),

                        InkWell(
                          onTap: ()=> Get.to(() => PolicyScreen(htmlType: HtmlType.termsAndConditions, image: Get.find<ConfigController>().config?.termsAndConditions?.image??'',)),
                          child: Padding(
                            padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                            child: Text(
                              "terms_and_condition".tr,
                              style: textRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeExtraSmall, decoration: TextDecoration.underline, decorationColor: Theme.of(context).hintColor),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]);
          }),
        ),
      ),
    );
  }

  Future<void> _onTap ({required SocialLoginType socialLoginType}) async {

    if(socialLoginType == SocialLoginType.google){

      final SocialLogInBody? socialLoginModel = await Get.find<AuthController>().googleLogin();


      if(socialLoginModel != null) {
        Get.find<AuthController>().loginWithSocialMedia(
          socialLoginModel
        );
      }
    }

    else if(socialLoginType == SocialLoginType.facebook){
      final SocialLogInBody? socialLoginModel =  await Get.find<AuthController>().facebookLogin();

      if(socialLoginModel != null) {
        Get.find<AuthController>().loginWithSocialMedia(socialLoginModel);
      }
    } else if(socialLoginType == SocialLoginType.apple){
      final credential = await SignInWithApple.getAppleIDCredential(scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);

      Get.find<AuthController>().loginWithSocialMedia(SocialLogInBody(
          email: credential.email, token: credential.authorizationCode, uniqueId: credential.authorizationCode, medium: "apple",
          userName: credential.givenName ?? credential.familyName
      ));
    }
  }
}

class _SocialButton extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({required this.image, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Theme.of(context).hintColor.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56, height: 56,
              child: Center(child: Image.asset(image, width: 24, height: 24, fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:ride_sharing_user_app/features/auth/domain/enums/verification_from_enum.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/auth_scaffold.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';

class VerificationScreen extends StatefulWidget {
  final String number;
  final VerificationForm form;
  final String? session;
  const VerificationScreen({super.key,required this.number,  required this.form, this.session});

  @override
  VerificationScreenState createState() => VerificationScreenState();
}

class VerificationScreenState extends State<VerificationScreen> {
  Timer? _timer;
  int? _seconds = 0;
  final pinCodeController = PinInputController();
  String errorText = '';

  @override
  void initState() {
    super.initState();
    Get.find<AuthController>().updateVerificationCode('',isUpdate: false);
    _startTimer();
  }

  void _startTimer() {
    _seconds = Get.find<ConfigController>().otpResendTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds = _seconds! - 1;
      if(_seconds == 0) {
        timer.cancel();
        _timer?.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    pinCodeController.clearError();
    pinCodeController.dispose();
    _timer?.cancel();
  }

  String get _maskedNumber => widget.number.length > 8
      ? '${widget.number.substring(0, 5)}*****${widget.number.substring(widget.number.length - 3, widget.number.length)}'
      : widget.number;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(builder: (authController) {
      final Color accent = Theme.of(context).primaryColor;
      final bool ready = authController.verificationCode.length == 6;

      return AuthScaffold(
        title: 'verification'.tr,
        subtitle: '${'we_have_send_a_varification_code_to'.tr} $_maskedNumber',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if(Get.find<ConfigController>().config?.isDemo ?? true)
            Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
              child: Text('for_demo_purpose_use'.tr, style: textSemiBold.copyWith(
                color: Theme.of(context).disabledColor,
              )),
            ),

          Center(
            child: MaterialPinField(
              length: 6,
              pinController: pinCodeController,
              theme: MaterialPinTheme(
                cellSize: const Size(46, 52),
                borderWidth: 1.5,
                borderRadius: BorderRadius.all(Radius.circular(Dimensions.radiusLarge)),
                cursorColor: Theme.of(context).textTheme.bodyMedium?.color,
                cursorHeight: 20,
                animationDuration: const Duration(milliseconds: 300),
                borderColor: Theme.of(context).hintColor.withValues(alpha:0.25),
                filledBorderColor: accent,
                fillColor: Theme.of(context).hintColor.withValues(alpha: 0.06),
                filledFillColor: accent.withValues(alpha: 0.06),
                focusedFillColor: Theme.of(context).cardColor,
                focusedBorderColor: accent,
              ),
              autoFocus: true,
              keyboardType: TextInputType.number,
              onChanged: (query){
                errorText = '';
                authController.updateVerificationCode(query);
              },
            ),
          ),

          if(errorText.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Center(child: Text(errorText, style: textRegular.copyWith(color: Theme.of(context).colorScheme.error))),
          ],
          const SizedBox(height: Dimensions.paddingSizeLarge),

          !authController.otpVerifying ?
          ButtonWidget(
            buttonText: 'verify'.tr,
            height: 52,
            radius: 16,
            backgroundColor: ready ? accent : Theme.of(context).hintColor.withValues(alpha: 0.25),
            textColor: ready ? Colors.white : Theme.of(context).hintColor,
            onPressed: ready ? () {
              authController.otpVerification(
                  widget.number, authController.verificationCode, from: widget.form,
                  session: widget.session
              ).then((value){
                if(value.statusCode == 403){
                  errorText = 'incorrect_otp'.tr;
                  pinCodeController.triggerError();
                }
              });
            } : null,
          ) :
          Center(child: SpinKitCircle(color: accent, size: 40.0)),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('did_not_receive_the_code'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
            const SizedBox(width: 6),

            _seconds! <= 0 ?
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if(Get.find<ConfigController>().config?.isFirebaseOtpVerification ?? false){

                  await authController.firebaseOtpSend(widget.number, canRoute: false, from: widget.form);
                  showCustomSnackBar('otp_sent_successfully'.tr, isError: false);

                  _startTimer();

                }else if(Get.find<ConfigController>().config?.isSmsGateway ?? false){
                  authController.sendOtp(widget.number).then((value){
                    if(value.statusCode == 200) {
                      _startTimer();
                    }
                  });
                }else{
                  showCustomSnackBar('sms_gateway_not_integrate'.tr);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('resend_code'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: accent)),
              ),
            ) :
            Text(
              '${'resend_it'.tr} (${_seconds}s)',
              style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: accent),
            ),
          ]),
        ]),
      );
    });
  }
}

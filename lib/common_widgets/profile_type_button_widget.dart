import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/wallet/controllers/wallet_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';


/// Wallet / Points switch at the top of the wallet screen, as filter pills.
class ProfileTypeButtonWidget extends StatelessWidget {
  final int index;
  final String profileTypeName;
  const ProfileTypeButtonWidget({super.key, required this.index, required this.profileTypeName});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WalletController>(builder: (walletController) {
      final bool selected = index == walletController.currentTabIndex;
      final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: ()=> selected ? null : walletController.updateCurrentTabIndex(index, isUpdate: true),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
            width: MediaQuery.of(context).size.width/2.5,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: selected ? Theme.of(context).primaryColor : Theme.of(context).hintColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              profileTypeName.tr,
              textAlign: TextAlign.center,
              style: textSemiBold.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: selected ? Colors.white : Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
      );
    });
  }
}

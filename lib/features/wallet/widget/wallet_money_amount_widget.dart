import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/wallet/widget/add_fund_dialog.dart';
import 'package:ride_sharing_user_app/features/wallet/widget/point_to_wallet_money_widget.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/wallet/controllers/wallet_controller.dart';

/// The balance card at the top of the wallet: an E-Ride ink card with a red
/// glow and the brand mark as a watermark. Wallet money gets an "Add money"
/// button when the admin allows top-ups; points get the conversion action
/// on tap, exactly as before.
class WalletMoneyAmountWidget extends StatelessWidget {
  final bool walletMoney;
  const  WalletMoneyAmountWidget({super.key,  this.walletMoney = false});

  @override
  Widget build(BuildContext context) {
    return  GetBuilder<WalletController>(builder: (walletController) {
      return GetBuilder<ProfileController>(
        initState: (context){
          Get.find<ProfileController>().getProfileInfo();
        },
        builder: (profileController) {
          final Color accent = Theme.of(context).primaryColor;
          final bool canAddFund = Get.find<ConfigController>().config?.walletAddFundStatus ?? false;
          final String amount = walletMoney
              ? PriceConverter.convertPrice(profileController.profileModel?.data?.wallet?.walletBalance ?? 0)
              : (profileController.profileModel?.data?.loyaltyPoints ?? '0').toString();

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeSmall,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if(!walletMoney) {
                      if(Get.find<ConfigController>().config?.conversionStatus ?? false) {
                        showDialog(barrierDismissible: false,
                          context: context, builder: (_) => const PointToWalletMoneyWidget(),
                        );
                      }else {
                        showCustomSnackBar('point_conversion_is_currently_unavailable'.tr);
                      }
                    }
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1A20), Color(0xFF0E0E12)],
                      ),
                    ),
                    child: Stack(children: [
                      Positioned(
                        top: -80, right: -40,
                        child: Container(
                          width: 240, height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [accent.withValues(alpha: 0.45), accent.withValues(alpha: 0)]),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -18, bottom: -26,
                        child: Opacity(
                          opacity: 0.10,
                          child: Image.asset(Images.brandMarkOnDark, height: 120, fit: BoxFit.contain),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Image.asset(
                                walletMoney ? Images.walletMoney : Images.loyaltyPoint,
                                height: 18, width: 18,
                              )),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Text(
                              walletMoney ? 'wallet_balance'.tr : 'your_points'.tr,
                              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white.withValues(alpha: 0.72)),
                            ),
                          ]),
                          const SizedBox(height: Dimensions.paddingSizeDefault),

                          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Expanded(child: Text(
                              amount,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: textBold.copyWith(fontSize: 30, color: Colors.white),
                            )),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            if (walletMoney && canAddFund)
                              _CardAction(
                                icon: Icons.add_rounded,
                                label: 'add_money'.tr,
                                onTap: ()=> Get.dialog(AddFundDialog(), barrierDismissible: false),
                              )
                            else if (!walletMoney)
                              _CardAction(icon: Icons.swap_horiz_rounded, label: 'convert'.tr),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _CardAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: const Color(0xFF15151A)),
            const SizedBox(width: 5),
            Text(label, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF15151A))),
          ]),
        ),
      ),
    );
  }
}

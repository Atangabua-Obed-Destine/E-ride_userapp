import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/address/screens/my_address.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_list.dart';
import 'package:ride_sharing_user_app/features/my_level/screens/my_level_screen.dart';
import 'package:ride_sharing_user_app/features/my_offer/screens/my_offer_screen.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/profile/screens/edit_profile_screen.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:ride_sharing_user_app/features/safety_setup/screens/safety_setup_screen.dart';
import 'package:ride_sharing_user_app/features/settings/screens/setting_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';
import 'package:ride_sharing_user_app/features/support/screens/support_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_screen.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Side drawer, opened from the home app bar.
///
/// The template had no drawer at all: every secondary destination lived behind
/// the Profile tab. This brings them one swipe away, the way Uber and Bolt do,
/// and reuses the exact screens and translation keys the Profile tab already
/// navigates to, so nothing here is a new destination.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = math.min(MediaQuery.sizeOf(context).width * 0.82, 340);
    final config = Get.find<ConfigController>().config;

    return Drawer(
      width: width,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(children: [
        const _DrawerHeader(),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
            children: [
              // The wallet only exists to pay with: hidden when the admin turns it off.
              if (config?.paymentWalletStatus ?? true)
                _DrawerTile(icon: Icons.account_balance_wallet_outlined, label: 'my_wallet', onTap: () => _go(context, const WalletScreen())),
              _DrawerTile(icon: Icons.local_offer_outlined, label: 'my_offer', onTap: () => _go(context, MyOfferScreen())),
              if (config?.levelStatus ?? false)
                _DrawerTile(icon: Icons.military_tech_outlined, label: 'my_level', onTap: () => _go(context, const MyLevelScreen())),
              _DrawerTile(icon: Icons.route_outlined, label: 'my_trips', onTap: () => _go(context, const TripScreen(fromProfile: true))),

              const _DrawerDivider(),

              _DrawerTile(icon: Icons.location_on_outlined, label: 'my_address', onTap: () => _go(context, const MyAddressScreen())),
              GetBuilder<ChatInboxController>(builder: (inbox) => _DrawerTile(
                icon: Icons.chat_bubble_outline_rounded, label: 'message', badge: inbox.totalUnread,
                onTap: () => _go(context, const MessageListScreen()),
              )),
              _DrawerTile(icon: Icons.shield_outlined, label: 'safety', onTap: () => _go(context, const SafetySetupScreen())),
              if (config?.referralEarningStatus ?? false)
                _DrawerTile(icon: Icons.card_giftcard_outlined, label: 'refer_and_earn', onTap: () => _go(context, const ReferAndEarnScreen())),

              const _DrawerDivider(),

              _DrawerTile(icon: Icons.help_outline_rounded, label: 'help_support', onTap: () => _go(context, const HelpAndSupportScreen())),
              _DrawerTile(icon: Icons.settings_outlined, label: 'settings', onTap: () => _go(context, const SettingScreen())),
            ],
          ),
        ),

        const _DrawerDivider(),
        _DrawerTile(
          icon: Icons.logout_rounded,
          label: 'logout',
          destructive: true,
          onTap: () => _confirmLogout(context),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall),
      ]),
    );
  }

  /// Close the drawer first so the destination does not slide in behind it.
  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Get.to(() => screen);
  }

  /// Same confirmation flow the Profile tab uses, so behaviour is identical.
  void _confirmLogout(BuildContext context) {
    Navigator.of(context).pop();
    Get.bottomSheet(
      GetBuilder<AuthController>(builder: (authController) {
        return ConfirmationBottomsheetWidget(
          icon: Images.exitIcon,
          title: 'Logout'.tr,
          description: 'do_you_want_to_log_out_this_account'.tr,
          iconColor: Theme.of(context).cardColor,
          isLoading: authController.isLoading,
          onYesPressed: () => Get.find<AuthController>().logOut(),
          onNoPressed: () => Get.back(),
        );
      }),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;

    return GetBuilder<ProfileController>(builder: (profileController) {
      final data = profileController.profileModel?.data;
      final String? imageBase = Get.find<ConfigController>().config?.imageBaseUrl?.profileImage;
      final String? avatar = (data?.profileImage != null && imageBase != null) ? '$imageBase/${data!.profileImage}' : null;
      final String contact = data?.phone ?? data?.email ?? '';

      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kSplashInkLow, kSplashInk],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -1.0),
                  radius: 1.3,
                  colors: [accent.withValues(alpha: 0.32), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeLarge, Dimensions.paddingSizeLarge,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset(Images.brandMarkOnDark, height: 22, alignment: Alignment.centerLeft),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2),
                    ),
                    child: ClipOval(
                      child: avatar != null
                          ? ImageWidget(image: avatar, width: 54, height: 54, placeholder: Images.personPlaceholder)
                          : Image.asset(Images.personPlaceholder, width: 54, height: 54, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeDefault),

                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        profileController.customerName().trim().isEmpty ? 'profile'.tr : profileController.customerName().trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(color: Colors.white, fontSize: 17),
                      ),
                      if (contact.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contact,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textRegular.copyWith(color: Colors.white.withValues(alpha: 0.6), fontSize: Dimensions.fontSizeSmall),
                        ),
                      ],
                    ]),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.of(context).pop();
                    Get.to(() => const EditProfileScreen());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('profile'.tr, style: textSemiBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final int badge;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final Color fg = destructive ? Theme.of(context).colorScheme.error : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge, vertical: 13),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (destructive ? Theme.of(context).colorScheme.error : accent).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: destructive ? Theme.of(context).colorScheme.error : accent),
          ),
          const SizedBox(width: Dimensions.paddingSizeDefault),
          Expanded(
            child: Text(label.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: fg)),
          ),
          CountPill(count: badge),
          if (!destructive)
            Icon(Icons.chevron_right_rounded, size: 20, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: Dimensions.paddingSizeDefault,
      thickness: 1,
      indent: Dimensions.paddingSizeLarge,
      endIndent: Dimensions.paddingSizeLarge,
      color: Theme.of(context).hintColor.withValues(alpha: 0.18),
    );
  }
}

import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/id_verification/screens/id_verification_screen.dart';
import 'package:ride_sharing_user_app/common_widgets/confirmation_bottomsheet_widget.dart';
import 'package:ride_sharing_user_app/features/address/screens/my_address.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_list.dart';
import 'package:ride_sharing_user_app/features/my_level/screens/my_level_screen.dart';
import 'package:ride_sharing_user_app/features/my_offer/screens/my_offer_screen.dart';
import 'package:ride_sharing_user_app/features/profile/widgets/profile_item.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:ride_sharing_user_app/features/safety_setup/screens/safety_setup_screen.dart';
import 'package:ride_sharing_user_app/features/trip_share/screens/trusted_contacts_screen.dart';
import 'package:ride_sharing_user_app/features/settings/domain/html_enum_types.dart';
import 'package:ride_sharing_user_app/features/settings/screens/setting_screen.dart';
import 'package:ride_sharing_user_app/features/support/screens/support_screen.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_screen.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/settings/screens/policy_screen.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/profile/screens/edit_profile_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/wallet/screens/wallet_screen.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';

/// Profile tab: an ink identity card (avatar, name, rating, level, ride and
/// point counts) followed by the menu grouped into Account / More / Legal
/// cards and a final danger card for logout and delete. Every destination
/// and both confirmation sheets are the ones the shipped screen used.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: GetBuilder<ProfileController>(builder: (profileController) {
          final config = Get.find<ConfigController>().config;
          final bool showReferral = (config?.referralEarningStatus ?? false) ||
              ((profileController.profileModel?.data?.wallet?.referralEarn ?? 0) > 0);
          final bool showLevel = config?.levelStatus ?? false;

          return BodyWidget(appBar: AppBarWidget(title: 'profile'.tr, showBackButton: false),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _IdentityCard(profileController: profileController, showLevel: showLevel),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                _SectionCard(title: 'profile_section_account'.tr, children: [
                  ProfileMenuItem(title: 'profile', icon: Images.profileProfile,
                    onTap: () => Get.to(() => const EditProfileScreen()),
                  ),
                  ProfileMenuItem(title: 'my_address', icon: Images.location,
                    onTap: () => Get.to(() => const MyAddressScreen()),
                  ),
                  ProfileMenuItem(title: 'id_menu', icon: Images.privacyPolicy,
                    onTap: () => Get.to(() => const IdVerificationScreen()),
                  ),
                  GetBuilder<ChatInboxController>(builder: (inbox) => ProfileMenuItem(title: 'message', icon: Images.profileMessage,
                    badge: inbox.totalUnread,
                    onTap: () => Get.to(() => const MessageListScreen()),
                  )),
                  // The wallet only exists to pay with: hidden when the admin turns it off.
                  if (Get.find<ConfigController>().config?.paymentWalletStatus ?? true)
                    ProfileMenuItem(title: 'my_wallet', icon: Images.profileMyWallet,
                      onTap: () => Get.to(() => const WalletScreen()),
                    ),
                  ProfileMenuItem(title: 'my_offer', icon: Images.paymentAndVoucher,
                    onTap: () => Get.to(() => MyOfferScreen()),
                  ),
                  ProfileMenuItem(title: 'my_trips', icon: Images.profileMyTrip, divider: false,
                    onTap: () => Get.to(() => const TripScreen(fromProfile: true)),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                _SectionCard(title: 'profile_section_more'.tr, children: [
                  ProfileMenuItem(title: 'safety', icon: Images.privacyPolicy,
                    onTap: () => Get.to(() => const SafetySetupScreen()),
                  ),
                  ProfileMenuItem(title: 'trusted_contacts', icon: Images.shareLocation,
                    onTap: () => Get.to(() => const TrustedContactsScreen()),
                  ),
                  if(showReferral)
                  ProfileMenuItem(title: 'refer_and_earn', icon: Images.referralIcon1,
                    onTap: () => Get.to(() => const ReferAndEarnScreen()),
                  ),
                  if(showLevel)
                  ProfileMenuItem(title: 'my_level', icon: Images.myLevelIcon,
                    onTap: () => Get.to(() => const MyLevelScreen()),
                  ),
                  ProfileMenuItem(title: 'help_support', icon: Images.profileHelpSupport,
                    onTap: () => Get.to(() => const HelpAndSupportScreen()),
                  ),
                  ProfileMenuItem(title: 'settings', icon: Images.profileSetting, divider: false,
                    onTap: () => Get.to(() => const SettingScreen()),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                _SectionCard(title: 'profile_section_legal'.tr, children: [
                  ProfileMenuItem(title: 'privacy_policy', icon: Images.privacyPolicyIcon,
                    onTap: () => Get.to(() =>  PolicyScreen(htmlType: HtmlType.privacyPolicy,
                      image: config?.privacyPolicy?.image??'',
                    )),
                  ),
                  ProfileMenuItem(title: 'refund_policy', icon: Images.privacyPolicyIcon,
                    onTap: () => Get.to(() =>  PolicyScreen(htmlType: HtmlType.refundPolicy,
                      image: config?.refundPolicy?.image??'',
                    )),
                  ),
                  ProfileMenuItem(title: 'terms_and_condition', icon: Images.termsAndCondition,
                    onTap: () => Get.to(() =>  PolicyScreen(htmlType: HtmlType.termsAndConditions,
                      image: config?.termsAndConditions?.image??'',
                    )),
                  ),
                  ProfileMenuItem(title: 'legal', icon: Images.privacyPolicy, divider: false,
                    onTap: () => Get.to(() =>  PolicyScreen(htmlType: HtmlType.legal,
                      image: config?.legal?.image??'',
                    )),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                _SectionCard(children: [
                  ProfileMenuItem(title: 'logout', icon: Images.profileLogout, danger: true,
                    onTap: () {
                      Get.bottomSheet(
                        GetBuilder<AuthController>(builder: (authController){
                          return ConfirmationBottomsheetWidget(
                            icon: Images.exitIcon,
                            title: 'Logout'.tr,
                            description: 'do_you_want_to_log_out_this_account'.tr,
                            iconColor: Theme.of(context).cardColor,
                            isLoading: authController.isLoading,
                            onYesPressed: (){
                              Get.find<AuthController>().logOut();
                            },
                            onNoPressed: ()=> Get.back(),
                          );
                        })
                      );
                    },
                  ),
                  ProfileMenuItem(title: 'permanently_delete_account'.tr,
                    icon: Images.deleteAccountIcon,
                    divider: false, danger: true,
                    onTap: () {
                      Get.bottomSheet(
                        GetBuilder<AuthController>(builder: (authController){
                          return ConfirmationBottomsheetWidget(
                            icon: Images.exitIcon,
                            title: 'delete_account'.tr,
                            description: 'are_you_sure_permanent_delete_smg'.tr,
                            iconColor: Theme.of(context).cardColor,
                            isLoading: authController.isLoading,
                            onYesPressed: (){
                              Get.find<AuthController>().permanentlyDelete();
                            },
                            onNoPressed: ()=> Get.back(),
                          );
                        })
                      );
                    },
                  ),
                ]),

                // Clears the floating nav dock.
                const SizedBox(height: 124),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

/// Dark identity card on the splash ink with a red glow, matching the drawer
/// header and the splash.
class _IdentityCard extends StatelessWidget {
  final ProfileController profileController;
  final bool showLevel;
  const _IdentityCard({required this.profileController, required this.showLevel});

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final data = profileController.profileModel?.data;
    final String? imageBase = Get.find<ConfigController>().config?.imageBaseUrl?.profileImage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A20), Color(0xFF0E0E12)],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: -70, right: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [accent.withValues(alpha: 0.42), accent.withValues(alpha: 0)]),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 2)),
                  child: ClipOval(
                    child: ImageWidget(
                      height: 62, width: 62,
                      image: data?.profileImage != null ? '$imageBase/${data?.profileImage ?? ''}' : '',
                      placeholder: Images.personPlaceholder, fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSize),

                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    profileController.customerName(),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC53D)),
                    const SizedBox(width: 3),
                    Text(
                      data?.userRating ?? '0',
                      style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white),
                    ),
                    if (showLevel) ...[
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 13, height: 13, child: ImageWidget(
                            image: '${AppConstants.baseUrl}/storage/app/public/customer/level/${data?.level?.image ?? ''}',
                          )),
                          const SizedBox(width: 5),
                          Text(
                            data?.level?.name ?? '0',
                            style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                ])),

                Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Get.to(() => const EditProfileScreen()),
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: Dimensions.paddingSizeDefault),

              Container(
                padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSize),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  _Stat(label: 'total_ride'.tr, value: '${data?.totalRideCount ?? 0}'),
                  Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.14)),
                  _Stat(label: 'total_point'.tr, value: '${data?.loyaltyPoints ?? 0}'),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(value, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: Colors.white)),
      const SizedBox(height: 2),
      Text(label, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white.withValues(alpha: 0.65))),
    ]));
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _SectionCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, Dimensions.paddingSizeSmall),
          child: Text(
            title!.toUpperCase(),
            style: textSemiBold.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              letterSpacing: 1.2,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    ]);
  }
}

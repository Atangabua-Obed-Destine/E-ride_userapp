import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/onboard/controllers/on_board_page_controller.dart';
import 'package:ride_sharing_user_app/features/onboard/widget/onboard_scenes.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/localization/language_selection_screen.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';

/// One onboarding page.
///
/// Built in `build()` rather than held in a const list because the headline and
/// body go through `.tr`. AppConstants.onBoardPagerData resolved `.tr` once, at
/// static-initialisation time, so its copy froze in whichever language happened
/// to be active first and never followed a language change.
///
/// The copy mixes English, French and (on the food page) Pidgin on purpose, the
/// way people talk in Cameroon. It reads the same whatever the phone's language,
/// so en.json and fr.json hold the same text for these keys.
class _Page {
  final OnboardScene scene;
  final String eyebrow;
  final String title;
  final String body;
  final String cta;
  const _Page(this.scene, this.eyebrow, this.title, this.body, this.cta);

  factory _Page.of(OnboardScene scene, String key) =>
      _Page(scene, 'onb_${key}_eyebrow'.tr, 'onb_${key}_title'.tr, 'onb_${key}_body'.tr, 'onb_${key}_cta'.tr);
}

class OnBoardingScreen extends StatefulWidget {
  final Map<String, dynamic>? notificationData;
  const OnBoardingScreen({super.key, required this.notificationData});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  /// Drives the illustration for the page currently on screen. Restarted on
  /// every page change so each scene plays its own entrance.
  late final AnimationController _art;

  @override
  void initState() {
    super.initState();
    _art = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _art.value = 1;
    } else if (!_art.isAnimating && _art.value == 0) {
      _art.forward();
    }
  }

  @override
  void dispose() {
    _art.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    Get.find<ConfigController>().disableIntro();
    if (Get.find<LocalizationController>().haveLocalLanguageCode()) {
      LoginHelper.checkLoginMedium();
    } else {
      Get.offAll(() => LanguageSelectionScreen(notificationData: widget.notificationData));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).primaryColor;

    // Every service, a page each (or a few together).
    final pages = <_Page>[
      _Page.of(OnboardScene.welcome, 'welcome'),
      _Page.of(OnboardScene.ride, 'ride'),
      _Page.of(OnboardScene.food, 'food'),
      _Page.of(OnboardScene.send, 'send'),
      _Page.of(OnboardScene.travel, 'travel'),
      _Page.of(OnboardScene.work, 'work'),
      _Page.of(OnboardScene.safe, 'safe'),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: kSplashInk,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kSplashInk,
        body: GetBuilder<OnBoardController>(builder: (onBoardController) {
          final index = onBoardController.pageIndex.clamp(0, pages.length - 1);
          final isLast = index == pages.length - 1;

          return Stack(fit: StackFit.expand, children: [
            SplashBackdrop(accent: accent),

            SafeArea(
              child: Column(children: [

                _TopBar(
                  accent: accent,
                  showSkip: !isLast,
                  onSkip: _finish,
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (value) {
                      onBoardController.onPageChanged(value);
                      _art
                        ..reset()
                        ..forward();
                    },
                    itemBuilder: (_, i) => _PageContent(
                      page: pages[i],
                      accent: accent,
                      // Only the visible page animates; the others sit finished
                      // so a quick swipe back never shows a half-drawn scene.
                      animation: i == index ? _art : const AlwaysStoppedAnimation(1.0),
                    ),
                  ),
                ),

                _ProgressBar(count: pages.length, index: index, accent: accent),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
                  child: _PrimaryButton(
                    label: pages[index].cta,
                    showArrow: !isLast,
                    accent: accent,
                    onTap: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
              ]),
            ),
          ]);
        }),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Color accent;
  final bool showSkip;
  final VoidCallback onSkip;
  const _TopBar({required this.accent, required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeLarge,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeSmall,
        0,
      ),
      child: Row(children: [
        // Dark-background logo variant; the shipped logo.png would lose its
        // mark against this canvas.
        Image.asset(Images.logoOnDark, height: 30),
        const Spacer(),
        AnimatedOpacity(
          opacity: showSkip ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: TextButton(
            onPressed: showSkip ? onSkip : null,
            child: Text(
              'onb_skip'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: Dimensions.fontSizeDefault,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _Page page;
  final Color accent;
  final Animation<double> animation;
  const _PageContent({required this.page, required this.accent, required this.animation});

  @override
  Widget build(BuildContext context) {
    // The words follow the cards in a moment after the page opens.
    final words = CurvedAnimation(parent: animation, curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // The scene takes what the words leave, and scales to fit it.
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
        child: OnboardScenes(scene: page.scene, animation: animation),
      )),
      FadeTransition(
        opacity: words,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(words),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, Dimensions.paddingSizeDefault, 28, Dimensions.paddingSizeLarge),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                page.eyebrow,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: Color(0xFFFF5A4F)),
              ),
              const SizedBox(height: 10),
              Text(
                page.title,
                style: const TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                page.body,
                style: TextStyle(fontSize: Dimensions.fontSizeDefault, height: 1.5, color: Colors.white.withValues(alpha: 0.72)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// Segmented progress instead of dots: it shows how far through you are, not
/// just which page you are on.
class _ProgressBar extends StatelessWidget {
  final int count;
  final int index;
  final Color accent;
  const _ProgressBar({required this.count, required this.index, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 4,
          width: active ? 26 : 8,
          decoration: BoxDecoration(
            color: active ? accent : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool showArrow;
  final Color accent;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.accent, required this.onTap, this.showArrow = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: TextStyle(color: Colors.white, fontSize: Dimensions.fontSizeLarge, fontWeight: FontWeight.w700)),
            if (showArrow) ...[
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ]),
        ),
      ),
    );
  }
}

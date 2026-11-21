import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Shell for every sign-in step (OTP, password, verification): the splash
/// canvas with the finished route drawn across it, a white title and
/// subtitle, and a white card that holds the form. One shell, so every auth
/// step looks like the same product as the splash and onboarding.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kSplashInk,
        body: Stack(children: [
          Positioned.fill(child: SplashBackdrop(accent: accent)),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.45,
                child: CustomPaint(
                  painter: RouteMapPainter(animation: const AlwaysStoppedAnimation<double>(1.0), accent: accent),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, Dimensions.paddingSizeLarge, 0),
                child: Row(children: [
                  if (showBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: Dimensions.paddingSizeDefault, height: 48),
                  const Spacer(),
                  Image.asset(Images.brandMarkOnDark, height: 26, fit: BoxFit.contain),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeLarge, Dimensions.paddingSizeSmall, Dimensions.paddingSizeLarge, 0,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: textBold.copyWith(fontSize: 26, color: Colors.white)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeLarge, Dimensions.paddingSizeExtraLarge, Dimensions.paddingSizeLarge, Dimensions.paddingSizeExtraLarge,
                    ),
                    child: child,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

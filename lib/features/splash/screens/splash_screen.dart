import 'dart:math' as math;
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/login_helper.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/splash/widgets/splash_backdrop.dart';

class SplashScreen extends StatefulWidget {
  final Map<String, dynamic>? notificationData;
  const SplashScreen({super.key, this.notificationData});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;

  /// Drives the one-shot entrance: map, route, logo, tagline.
  late final AnimationController _intro;

  /// Loops for as long as the splash is up, driving the loading bar. The splash
  /// waits on the /configuration call, so there is no sensible fixed duration.
  late final AnimationController _pulse;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineFade;
  late final Animation<double> _taglineSlide;
  late final Animation<double> _chromeFade;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

    _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0.14, 0.52, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.14, 0.62, curve: Curves.easeOutCubic)),
    );
    _taglineFade = CurvedAnimation(parent: _intro, curve: const Interval(0.42, 0.78, curve: Curves.easeOut));
    _taglineSlide = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic)),
    );
    _chromeFade = CurvedAnimation(parent: _intro, curve: const Interval(0.60, 1.0, curve: Curves.easeOut));

    // Unchanged boot sequence. Everything below this line is the original flow.
    Get.find<ConfigController>().initSharedData();

    _checkConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "remove animations" accessibility setting: show the final
    // composition immediately rather than animating into it.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce == _reduceMotion && (_intro.isAnimating || _intro.value > 0)) return;
    _reduceMotion = reduce;
    if (reduce) {
      _intro.value = 1;
      _pulse.stop();
    } else {
      _intro.forward();
      _pulse.repeat();
    }
  }

  // Startup runs once at a time and stops once it has routed. Every network
  // change used to restart it, which could open the home screen twice or
  // route without a configuration (and crash) on a flaky connection.
  bool _starting = false;
  bool _started = false;
  Timer? _retry;
  int _attempts = 0;

  Future<void> _start() async {
    if (_starting || _started || !mounted) return;
    _starting = true;
    final bool routed = await LoginHelper().handleIncomingLinks(widget.notificationData);
    _starting = false;
    if (routed) {
      _started = true;
      _retry?.cancel();
      _onConnectivityChanged?.cancel();
    } else if (mounted) {
      // Configuration did not load: try again, backing off (4, 8, 16, then 30 s).
      _attempts++;
      _retry?.cancel();
      _retry = Timer(Duration(seconds: _attempts >= 4 ? 30 : 2 << _attempts), _start);
    }
  }

  void _checkConnectivity() {
    bool isFirst = true;
    _onConnectivityChanged = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      // Any network counts, not only Wi-Fi and mobile data: a phone on a VPN, a wired
      // connection or the iOS simulator reports another kind and is just as online.
      bool isConnected = result.any((ConnectivityResult r) => r != ConnectivityResult.none);
      if (!isFirst || !isConnected) {
        ScaffoldMessenger.of(Get.context!).removeCurrentSnackBar();
        ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar();
        ScaffoldMessenger.of(Get.context!).showSnackBar(SnackBar(
          backgroundColor: isConnected ? Colors.green : Colors.red,
          duration: Duration(seconds: isConnected ? 3 : 6000),
          content: Text(
            isConnected ? 'connected'.tr : 'no_connection'.tr,
            textAlign: TextAlign.center,
          ),
        ));
        if (isConnected) {
          _start();
        }
      } else {
        ScaffoldMessenger.of(Get.context!).removeCurrentSnackBar();
        ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar();
        _start();
      }
      isFirst = false;
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _onConnectivityChanged?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The canvas is dark in both themes, so the status bar icons must be
      // light regardless of the device's light/dark setting.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: kSplashInk,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: kSplashInk,
        body: Stack(fit: StackFit.expand, children: [

          SplashBackdrop(accent: accent),

          // The route drawing itself across the city. Repaints off the
          // controller directly, so no setState per frame.
          CustomPaint(
            painter: RouteMapPainter(animation: _intro, accent: accent),
          ),

          const SplashLogoScrim(),

          SafeArea(
            child: Column(children: [
              const Spacer(flex: 6),

              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: _LogoGlow(accent: accent),
                ),
              ),

              const SizedBox(height: 22),

              AnimatedBuilder(
                animation: _intro,
                builder: (_, child) => Opacity(
                  opacity: _taglineFade.value,
                  child: Transform.translate(offset: Offset(0, _taglineSlide.value), child: child),
                ),
                child: const _Tagline(),
              ),

              const Spacer(flex: 5),

              FadeTransition(
                opacity: _chromeFade,
                child: SplashLoadingBar(
                  animation: _pulse,
                  accent: accent,
                  animate: !_reduceMotion,
                ),
              ),

              const SizedBox(height: 34),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The lockup with a soft brand glow behind it.
///
/// Uses the dark-background variant of the logo: the shipped logo.png mixes
/// near-black and white elements, so on a dark canvas its mark disappears.
/// logo_on_dark.png is the same artwork with the greyscale parts mapped to
/// white, leaving the brand red untouched.
class _LogoGlow extends StatelessWidget {
  final Color accent;
  const _LogoGlow({required this.accent});

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.58, 260.0);
    return SizedBox(
      width: width * 1.9,
      height: width * 1.9,
      child: Stack(alignment: Alignment.center, children: [
        // Radial rather than a BoxShadow: a shadow would trace the image's
        // rectangular bounds and read as a glowing box behind the logo.
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: 0.34), Colors.transparent],
              stops: const [0.0, 0.72],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Image.asset(Images.logoOnDark, width: width, fit: BoxFit.contain),
      ]),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 46, height: 2, color: Colors.white.withValues(alpha: 0.16)),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          // The company's own tagline, straight from the logo artwork. Not a
          // translatable UI string: it is part of the brand.
          'EMMY\'S RELIABLE INTEGRATED\nDELIVERY & EXPRESS',
          textAlign: TextAlign.center,
          // Decorative brand text: allow a little growth for readability, but
          // not so much that it pushes the lockup off a small screen.
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
          style: TextStyle(
            fontSize: 10,
            height: 1.7,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    ]);
  }
}

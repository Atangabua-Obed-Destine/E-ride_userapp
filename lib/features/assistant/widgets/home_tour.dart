import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/activity/widgets/activity_bubble.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Three steps on Home, once, for a new customer: the services, the activity
/// button, and Ask E-Ride. The rest of the screen dims around each.
class HomeTour {
  static final GlobalKey servicesKey = GlobalKey(debugLabel: 'tour_services');
  static final GlobalKey askKey = GlobalKey(debugLabel: 'tour_ask');
  static bool _showing = false;

  /// The tour ran since the app started: Home keeps its "Did you know?" cards for another day.
  static bool ranThisSession = false;

  /// Whether this account has seen the tour.
  static bool doneFor(String userId) => Get.find<SharedPreferences>().getBool('home_tour_done_$userId') ?? false;

  static Future<void> maybeShow() async {
    final prefs = Get.find<SharedPreferences>();
    // Once per account, not per phone: a new customer on a shared phone still gets it.
    // The profile loads with Home; without it, the next Home load tries again.
    final profile = Get.find<ProfileController>();
    if (profile.profileModel?.data?.id == null) await profile.getProfileInfo();
    final userId = profile.profileModel?.data?.id;
    if (userId == null || userId.isEmpty) return;
    final doneKey = 'home_tour_done_$userId';
    if (_showing || (prefs.getBool(doneKey) ?? false)) return;
    final ctx = servicesKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    _showing = true;
    ranThisSession = true;
    await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
    await Future.delayed(const Duration(milliseconds: 350));
    final steps = <_Step>[
      _Step(() => _rectOf(servicesKey), 'tour_services_title'.tr, 'tour_services_body'.tr, scrollTo: servicesKey),
      _Step(_bubbleRect, 'tour_activity_title'.tr, 'tour_activity_body'.tr, bubble: true),
      if (Get.find<AssistantController>().enabled && askKey.currentContext != null)
        _Step(() => _rectOf(askKey), 'tour_ask_title'.tr, 'tour_ask_body'.tr, scrollTo: askKey),
    ];
    await Get.dialog(_TourOverlay(steps: steps), barrierColor: Colors.transparent, barrierDismissible: false, useSafeArea: false);
    _setBubble(false);
    prefs.setBool(doneKey, true);
    _showing = false;
    // The "Did you know?" card waits for the tour; it can show now.
    if (Get.isRegistered<AssistantController>()) Get.find<AssistantController>().update();
  }

  static Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where the floating button sits (the same sums as ActivityBubble).
  static Rect? _bubbleRect() {
    final c = Get.find<ActivityController>();
    final media = MediaQuery.of(Get.context!);
    const box = ActivityBubble.size + 12;
    final top = media.padding.top + 8;
    final bottom = media.size.height - media.padding.bottom - box - 8;
    final x = c.onRight ? media.size.width - box - 4 : 4.0;
    final y = (c.heightShare * media.size.height).clamp(top, bottom);
    return Rect.fromLTWH(x, y, box, box);
  }

  static void _setBubble(bool on) {
    if (!Get.isRegistered<ActivityController>()) return;
    final c = Get.find<ActivityController>();
    c.tourShowing = on;
    c.update();
  }
}

class _Step {
  final Rect? Function() target;
  final String title;
  final String body;
  final bool bubble;

  /// Scrolled into view before the step shows, clear of the floating search bar.
  final GlobalKey? scrollTo;
  _Step(this.target, this.title, this.body, {this.bubble = false, this.scrollTo});
}

class _TourOverlay extends StatefulWidget {
  final List<_Step> steps;
  const _TourOverlay({required this.steps});

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _i = 0;
  Rect? _last;
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    _apply();
    // Home can still be loading under the tour (banners, the food strip), which
    // moves what a step points at: follow it instead of keeping a stale hole.
    _watch = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      final now = widget.steps[_i].target();
      if (now != _last) setState(() {});
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  void _apply() => WidgetsBinding.instance.addPostFrameCallback((_) async {
        final step = widget.steps[_i];
        HomeTour._setBubble(step.bubble);
        final ctx = step.scrollTo?.currentContext;
        if (ctx != null && ctx.mounted) {
          await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.3);
        }
        if (mounted) setState(() {});
      });

  void _next() {
    if (_i == widget.steps.length - 1) {
      Get.back();
      return;
    }
    setState(() => _i++);
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = widget.steps[_i];
    final size = MediaQuery.sizeOf(context);
    _last = step.target();
    final target = _last?.inflate(8);
    final below = target == null || target.center.dy < size.height / 2;
    final last = _i == widget.steps.length - 1;

    final card = Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(22),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('tour_step'.trParams({'n': '${_i + 1}', 'of': '${widget.steps.length}'}).toUpperCase(),
              style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, letterSpacing: 0.8, color: theme.primaryColor)),
          const SizedBox(height: 6),
          Text(step.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 6),
          Text(step.body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: theme.hintColor)),
          const SizedBox(height: 12),
          Row(children: [
            if (!last) TextButton(onPressed: () => Get.back(), child: Text('tour_skip'.tr, style: textMedium.copyWith(color: theme.hintColor))),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.primaryColor, minimumSize: const Size(96, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
              onPressed: _next,
              child: Text(last ? 'tour_done'.tr : 'next'.tr, style: textBold.copyWith(color: Colors.white)),
            ),
          ]),
        ]),
      ),
    );

    return Stack(children: [
      Positioned.fill(child: GestureDetector(
        onTap: _next,
        child: CustomPaint(painter: _Dim(hole: target, color: Colors.black.withValues(alpha: 0.66))),
      )),
      Positioned(
        left: 20,
        right: 20,
        top: below ? ((target?.bottom ?? size.height * 0.3) + 16).clamp(40.0, size.height - 260) : null,
        bottom: below ? null : (size.height - target.top + 16).clamp(40.0, size.height - 260),
        child: card,
      ),
    ]);
  }
}

/// The dim layer, with a rounded hole around what the step points at.
class _Dim extends CustomPainter {
  final Rect? hole;
  final Color color;
  _Dim({required this.hole, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(all, Paint()..color = color);
      return;
    }
    final cut = Path()..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(22)));
    canvas.drawPath(Path.combine(PathOperation.difference, all, cut), Paint()..color = color);
    canvas.drawRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(22)),
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _Dim old) => old.hole != hole || old.color != color;
}

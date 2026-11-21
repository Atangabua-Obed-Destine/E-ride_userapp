import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/images.dart';

/// One onboarding page per group of services, each showing what the service
/// looks like in the app: small cards that slide in one after another.
///
/// Drawn on a fixed 390 × 430 stage (the designs' coordinates) and scaled to the
/// space the page has, so the composition holds on every phone.
enum OnboardScene { welcome, ride, food, send, travel, work, safe }

const Color _ink = Color(0xFF17171A);
const Color _muted = Color(0xFF5F5F68);
const Color _cardDark = Color(0xFF26272D);
const Color _soft = Color(0xFFB9B9C2);
const Color _red = Color(0xFFE02020);
const Color _green = Color(0xFF12804A);
const Color _blue = Color(0xFF1D4ED8);

class OnboardScenes extends StatelessWidget {
  final OnboardScene scene;
  final Animation<double> animation;
  const OnboardScenes({super.key, required this.scene, required this.animation});

  static const double stageWidth = 390;
  static const double stageHeight = 430;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: stageWidth,
        height: stageHeight,
        child: Stack(clipBehavior: Clip.none, children: switch (scene) {
          OnboardScene.welcome => _welcome(),
          OnboardScene.ride => _ride(),
          OnboardScene.food => _food(),
          OnboardScene.send => _send(),
          OnboardScene.travel => _travel(),
          OnboardScene.work => _work(),
          OnboardScene.safe => _safe(),
        }),
      ),
    );
  }

  // ---------------------------------------------------------------- helpers

  /// A card that fades and slides into place, starting at [start] (0..1) of the page's animation.
  Widget _in(double left, double top, double start, Widget child, {Offset from = const Offset(0, 0.18), double? width}) {
    final curve = CurvedAnimation(parent: animation, curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(position: Tween<Offset>(begin: from, end: Offset.zero).animate(curve), child: child),
      ),
    );
  }

  static Widget _t(String text, {double size = 14, FontWeight weight = FontWeight.w700, Color color = _ink, double? spacing, int? lines}) => Text(
        text,
        maxLines: lines,
        overflow: lines == null ? null : TextOverflow.ellipsis,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.25),
      );

  static BoxDecoration _white([double r = 22]) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 18))],
      );

  static BoxDecoration _dark([double r = 20]) => BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 34, offset: Offset(0, 16))],
      );

  static Widget _tile(Widget child, Color bg, {double size = 52, double r = 16}) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r)), alignment: Alignment.center, child: child);

  static Widget _img(String asset, {double? width, double? height}) => Image.asset(asset, width: width, height: height, fit: BoxFit.contain);

  static Widget _pill(String text, {Color bg = _red, Color fg = Colors.white, double height = 32}) => Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
        child: _t(text, size: 13, color: fg),
      );

  static Widget _glow(double left, double top, double size, Color color) =>
      Positioned(left: left, top: top, child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)));

  // ---------------------------------------------------------------- 1 welcome

  List<Widget> _welcome() {
    Widget ring(double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
        );
    Widget service(Widget child, Color bg) => Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: child,
        );
    // Eight services around the logo, appearing one after another round the ring.
    final around = <(double, double, Widget, Color)>[
      (163, 63, _img(Images.rideTile, width: 50), Colors.white),
      (262, 104, _img(Images.foodTile, height: 46), const Color(0xFFFFF4E6)),
      (303, 203, _img(Images.parcelTile, width: 46), const Color(0xFFF6EFE6)),
      (262, 302, const Icon(Icons.directions_bus_rounded, color: _blue, size: 34), const Color(0xFFE8F0FF)),
      (163, 343, _img(Images.stayTile, height: 46), const Color(0xFFF3EEFF)),
      (64, 302, _img(Images.exploreTile, width: 46), const Color(0xFFEAF7F3)),
      (23, 203, _img(Images.moveTile, width: 46), const Color(0xFFFFF0EE)),
      (64, 104, const Icon(Icons.storefront_rounded, color: Color(0xFF334155), size: 32), const Color(0xFFEEF2F7)),
    ];
    return [
      Positioned(left: 55, top: 95, child: ring(280)),
      Positioned(left: 95, top: 135, child: ring(200)),
      _in(135, 175, 0.0, Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F24),
          shape: BoxShape.circle,
          border: Border.all(color: _red, width: 2),
          boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.12), spreadRadius: 10)],
        ),
        child: _img(Images.logoOnDark, width: 84),
      ), from: Offset.zero),
      for (int i = 0; i < around.length; i++)
        _in(around[i].$1, around[i].$2, 0.08 + i * 0.06, service(around[i].$3, around[i].$4), from: const Offset(0, 0.35)),
    ];
  }

  // ---------------------------------------------------------------- 2 get around

  List<Widget> _ride() => [
        _in(24, 26, 0.0, Container(
          width: 342,
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: const Color(0xFF1D1E23), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            Positioned(left: 132, top: 128, child: Container(
              width: 76,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10))]),
              child: _img(Images.rideTile, width: 62),
            )),
          ]),
        ), from: Offset.zero),
        _in(40, 46, 0.15, Container(
          width: 236,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _white(18),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFFDECEC), shape: BoxShape.circle),
                child: const Icon(Icons.person_outline_rounded, color: _red, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t('onb_ride_driver'.tr),
              const SizedBox(height: 2),
              _t('onb_ride_driver_sub'.tr, size: 12, weight: FontWeight.w400, color: _muted),
            ])),
          ]),
        )),
        _in(142, 300, 0.3, Container(
          width: 224,
          padding: const EdgeInsets.all(12),
          decoration: _dark(18),
          child: Row(children: [
            _tile(_img(Images.scheduleTile, width: 36), Colors.white, size: 46, r: 14),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t('onb_ride_later'.tr, color: Colors.white),
              const SizedBox(height: 2),
              _t('onb_ride_later_sub'.tr, size: 12, weight: FontWeight.w400, color: _soft),
            ])),
          ]),
        )),
        _in(24, 372, 0.45, Container(
          height: 44,
          padding: const EdgeInsets.only(left: 12, right: 16),
          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 12))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            _t('onb_ride_health'.tr, color: Colors.white),
          ]),
        )),
      ];

  // ---------------------------------------------------------------- 3 food & shops

  List<Widget> _food() {
    Widget dish(String name, String price, Widget action, {bool off = false}) => Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _t(name, color: off ? const Color(0xFF8A8A93) : _ink),
            const SizedBox(height: 2),
            _t(price, size: 13, weight: off ? FontWeight.w600 : FontWeight.w400, color: off ? const Color(0xFFB42318) : _muted),
          ])),
          action,
        ]);
    const divider = Divider(height: 22, thickness: 1, color: Color(0xFFEFEFF2));
    return [
      _glow(250, 8, 150, const Color(0xFF3A2A1A)),
      _in(24, 30, 0.0, Container(
        width: 312,
        padding: const EdgeInsets.all(16),
        decoration: _white(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _tile(_img(Images.foodTile, height: 40), const Color(0xFFFFF4E6)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t('onb_food_store'.tr, size: 16, weight: FontWeight.w800),
              const SizedBox(height: 2),
              _t('onb_food_open'.tr, size: 12, weight: FontWeight.w600, color: _green),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFFB42318)),
              const SizedBox(width: 6),
              Expanded(child: _t('onb_food_branch'.tr, size: 12, weight: FontWeight.w600, color: const Color(0xFFB42318), lines: 1)),
            ]),
          ),
          const SizedBox(height: 14),
          dish('onb_food_dish1'.tr, 'onb_food_price1'.tr, _pill('onb_food_add'.tr)),
          divider,
          dish('onb_food_dish2'.tr, 'onb_food_price2'.tr, Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _red, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.remove_rounded, color: _red, size: 16),
              const SizedBox(width: 10),
              _t('1', color: _red, weight: FontWeight.w800),
              const SizedBox(width: 10),
              const Icon(Icons.add_rounded, color: _red, size: 16),
            ]),
          )),
          divider,
          dish('onb_food_dish3'.tr, 'onb_food_sold_out'.tr, _t('onb_food_elsewhere'.tr, size: 12, color: _green), off: true),
        ]),
      ), from: const Offset(0, 0.1)),
      _in(118, 330, 0.3, Container(
        width: 248,
        padding: const EdgeInsets.all(14),
        decoration: _dark(),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _t('onb_food_confirmed'.tr, color: Colors.white),
            const SizedBox(height: 3),
            _t('onb_food_pay'.tr, size: 12, weight: FontWeight.w600, color: const Color(0xFFFF8A80)),
          ])),
        ]),
      )),
    ];
  }

  // ---------------------------------------------------------------- 4 parcels & move

  List<Widget> _send() {
    Widget step(String label, {String? right, required int kind, bool last = false}) {
      // kind: 0 done, 1 current, 2 to come
      final Widget dot = switch (kind) {
        0 => Container(width: 18, height: 18, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12)),
        1 => Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _red, width: 5))),
        _ => Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD4D4DA), width: 2))),
      };
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          dot,
          if (!last) Container(width: 2, height: 22, color: kind == 0 ? _red : const Color(0xFFE4E4E8)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Row(children: [
          Expanded(child: _t(label, size: 13, weight: kind == 1 ? FontWeight.w700 : FontWeight.w600, color: kind == 2 ? const Color(0xFF8A8A93) : _ink)),
          if (right != null) _t(right, size: 13, weight: kind == 1 ? FontWeight.w700 : FontWeight.w400, color: kind == 1 ? const Color(0xFFB42318) : _muted),
        ])),
      ]);
    }

    return [
      _glow(-40, 210, 170, const Color(0xFF2E2418)),
      _in(54, 28, 0.0, Container(
        width: 312,
        padding: const EdgeInsets.all(16),
        decoration: _white(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _tile(_img(Images.parcelTile, width: 40), const Color(0xFFF6EFE6)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t('onb_send_parcel'.tr, size: 16, weight: FontWeight.w800),
              const SizedBox(height: 2),
              _t('onb_send_parcel_sub'.tr, size: 12, weight: FontWeight.w400, color: _muted),
            ])),
          ]),
          const SizedBox(height: 14),
          step('onb_send_picked'.tr, right: '14:05', kind: 0),
          step('onb_send_on_way'.tr, right: 'onb_send_eta'.tr, kind: 1),
          step('onb_send_delivered'.tr, kind: 2, last: true),
          const SizedBox(height: 14),
          Container(
            height: 40,
            decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_outlined, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              _t('onb_send_follow'.tr, size: 13, color: Colors.white),
            ]),
          ),
        ]),
      ), from: const Offset(0, 0.1)),
      _in(24, 316, 0.3, Container(
        width: 262,
        padding: const EdgeInsets.all(12),
        decoration: _dark(),
        child: Row(children: [
          _tile(_img(Images.moveTile, width: 44), Colors.white, size: 54),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _t('onb_send_move'.tr, color: Colors.white),
            const SizedBox(height: 3),
            _t('onb_send_move_sub'.tr, size: 12, weight: FontWeight.w400, color: _soft),
          ])),
        ]),
      )),
    ];
  }

  // ---------------------------------------------------------------- 5 bus, hotels & explore

  List<Widget> _travel() {
    Widget seat(String s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(8)),
          child: _t(s, size: 12, color: _blue),
        );
    return [
      _glow(230, 20, 170, const Color(0xFF1B2440)),
      _in(24, 26, 0.0, Container(
        width: 296,
        clipBehavior: Clip.antiAlias,
        decoration: _white(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            color: _blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: _t('onb_travel_ticket'.tr, size: 13, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: _t('onb_travel_verified'.tr, size: 11, color: Colors.white),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _t('Bamenda', size: 17, weight: FontWeight.w800),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, color: _blue, size: 16)),
                  _t('Yaoundé', size: 17, weight: FontWeight.w800),
                ]),
                const SizedBox(height: 8),
                _t('onb_travel_when'.tr, size: 12, weight: FontWeight.w400, color: _muted),
                const SizedBox(height: 8),
                Row(children: [seat('onb_travel_seat1'.tr), const SizedBox(width: 6), seat('onb_travel_seat2'.tr)]),
              ])),
              const SizedBox(width: 14),
              const SizedBox(width: 60, height: 60, child: CustomPaint(painter: _QrPainter())),
            ]),
          ),
        ]),
      ), from: const Offset(0, 0.1)),
      _in(96, 230, 0.3, Container(
        width: 270,
        padding: const EdgeInsets.all(12),
        decoration: _dark(),
        child: Column(children: [
          Row(children: [
            _tile(_img(Images.stayTile, height: 38), const Color(0xFFF3EEFF), size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t('onb_travel_room'.tr, color: Colors.white),
              const SizedBox(height: 3),
              _t('onb_travel_room_sub'.tr, size: 12, weight: FontWeight.w600, color: const Color(0xFFC9B8FF)),
            ])),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: _pill('onb_travel_go'.tr, height: 38)),
        ]),
      )),
      _in(24, 370, 0.45, Container(
        height: 46,
        padding: const EdgeInsets.only(left: 6, right: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 26, offset: Offset(0, 12))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFFEAF7F3), shape: BoxShape.circle),
              alignment: Alignment.center, child: _img(Images.exploreTile, width: 28)),
          const SizedBox(width: 10),
          _t('onb_travel_places'.tr, size: 13),
        ]),
      )),
    ];
  }

  // ---------------------------------------------------------------- 6 market, jobs & homes

  List<Widget> _work() {
    Widget label(String text, Color color) => _t(text, size: 11, weight: FontWeight.w800, color: color, spacing: 0.9);
    return [
      _glow(-30, 40, 160, const Color(0xFF1F2A26)),
      _in(24, 30, 0.0, Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: _white(),
        child: Row(children: [
          _tile(const Icon(Icons.storefront_rounded, color: Color(0xFF334155), size: 26), const Color(0xFFEEF2F7), size: 50, r: 15),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('onb_work_market'.tr, const Color(0xFF475569)),
            const SizedBox(height: 3),
            _t('onb_work_item'.tr),
            const SizedBox(height: 2),
            _t('onb_work_item_sub'.tr, size: 12, weight: FontWeight.w400, color: _muted),
          ])),
          _pill('onb_work_chat'.tr, bg: _ink),
        ]),
      )),
      _in(66, 150, 0.2, Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: _dark(22),
        child: Column(children: [
          Row(children: [
            _tile(const Icon(Icons.work_outline_rounded, color: Color(0xFF8A5A00), size: 26), const Color(0xFFFFF6DB), size: 50, r: 15),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label('onb_work_jobs'.tr, const Color(0xFFF5C451)),
              const SizedBox(height: 3),
              _t('onb_work_job'.tr, color: Colors.white),
              const SizedBox(height: 2),
              _t('onb_work_job_sub'.tr, size: 12, weight: FontWeight.w400, color: _soft),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1B1C21), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(width: 30, height: 30, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                  child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              for (final h in const [8.0, 16.0, 11.0, 20.0, 13.0, 7.0, 15.0, 10.0, 18.0, 9.0])
                Container(width: 3, height: h, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: const Color(0xFF6E6E78), borderRadius: BorderRadius.circular(2))),
              const Spacer(),
              _t('onb_work_voice'.tr, size: 12, weight: FontWeight.w600, color: _soft),
            ]),
          ),
        ]),
      )),
      _in(24, 300, 0.4, Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: _white(),
        child: Row(children: [
          _tile(const Icon(Icons.home_outlined, color: Color(0xFF0F766E), size: 26), const Color(0xFFEAF7F3), size: 50, r: 15),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('onb_work_homes'.tr, const Color(0xFF0F766E)),
            const SizedBox(height: 3),
            _t('onb_work_home'.tr),
            const SizedBox(height: 2),
            _t('onb_work_home_sub'.tr, size: 12, weight: FontWeight.w400, color: _muted),
          ])),
          _pill('onb_work_visit'.tr),
        ]),
      )),
    ];
  }

  // ---------------------------------------------------------------- 7 pay & stay safe

  List<Widget> _safe() {
    Widget row(IconData icon, Color fg, Color bg, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            _tile(Icon(icon, color: fg, size: 22), bg, size: 42, r: 13),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t(title),
              const SizedBox(height: 2),
              _t(sub, size: 12, weight: FontWeight.w400, color: _muted),
            ])),
          ]),
        );
    const divider = Divider(height: 1, thickness: 1, color: Color(0xFFEFEFF2));
    return [
      _in(24, 40, 0.1, Container(
        width: 342,
        padding: const EdgeInsets.fromLTRB(16, 46, 16, 10),
        decoration: _white(26),
        child: Column(children: [
          row(Icons.phone_android_rounded, const Color(0xFF8A5A00), const Color(0xFFFFF6DB), 'onb_safe_pay'.tr, 'onb_safe_pay_sub'.tr),
          divider,
          row(Icons.share_outlined, _blue, const Color(0xFFE8F0FF), 'onb_safe_share'.tr, 'onb_safe_share_sub'.tr),
          divider,
          row(Icons.notifications_none_rounded, const Color(0xFFB42318), const Color(0xFFFDECEC), 'onb_safe_checkin'.tr, 'onb_safe_checkin_sub'.tr),
          divider,
          row(Icons.badge_outlined, _green, const Color(0xFFE7F6EE), 'onb_safe_id'.tr, 'onb_safe_id_sub'.tr),
        ]),
      ), from: const Offset(0, 0.08)),
      _in(160, 0, 0.0, Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.14), spreadRadius: 10)],
        ),
        child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 34),
      ), from: const Offset(0, -0.3)),
    ];
  }
}

/// Streets and the red route for the ride card.
class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()..color = const Color(0xFF2A2B32)..strokeWidth = 10;
    for (final y in [70.0, 160.0, 240.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), street);
    }
    for (final x in [70.0, 170.0, 270.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), street);
    }
    final small = Paint()..color = const Color(0xFF24252B)..strokeWidth = 6;
    canvas.drawLine(const Offset(0, 110), Offset(size.width, 40), small);
    canvas.drawLine(const Offset(40, 300), const Offset(310, 0), small);

    final route = Path()
      ..moveTo(62, 252)
      ..cubicTo(90, 200, 140, 220, 170, 160)
      ..cubicTo(200, 100, 250, 110, 286, 64);
    canvas.drawPath(route, Paint()..color = _red..strokeWidth = 5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    canvas.drawCircle(const Offset(62, 252), 9, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(62, 252), 9, Paint()..color = _red..style = PaintingStyle.stroke..strokeWidth = 4);
    final pin = Path()
      ..moveTo(286, 82)
      ..cubicTo(286, 82, 270, 68, 270, 56)
      ..arcToPoint(const Offset(302, 56), radius: const Radius.circular(16))
      ..cubicTo(302, 68, 286, 82, 286, 82)
      ..close();
    canvas.drawPath(pin, Paint()..color = _red);
    canvas.drawCircle(const Offset(286, 56), 5.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A tiny made-up QR code for the ticket.
class _QrPainter extends CustomPainter {
  const _QrPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 7;
    final dark = Paint()..color = _ink;
    final light = Paint()..color = Colors.white;
    void sq(double x, double y, double w, Paint p) => canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, w * cell, w * cell), p);
    for (final (x, y) in const [(0.0, 0.0), (4.0, 0.0), (0.0, 4.0)]) {
      sq(x, y, 3, dark);
      sq(x + 1, y + 1, 1, light);
    }
    for (final (x, y) in const [(4.0, 4.0), (6.0, 4.0), (5.0, 5.0), (4.0, 6.0), (6.0, 6.0)]) {
      sq(x, y, 1, dark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

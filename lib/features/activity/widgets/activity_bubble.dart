import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/activity/widgets/activity_sheet.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The floating activity button, over every screen. The customer drags it
/// anywhere; it settles on the nearest side and stays there next time. A red
/// count means something needs them; a grey one, things in progress.
class ActivityBubble extends StatefulWidget {
  const ActivityBubble({super.key});

  static const double size = 56;

  @override
  State<ActivityBubble> createState() => _ActivityBubbleState();
}

class _ActivityBubbleState extends State<ActivityBubble> with SingleTickerProviderStateMixin {
  Offset? _drag;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ActivityController>()) return const SizedBox.shrink();
    return GetBuilder<ActivityController>(builder: (c) {
      final media = MediaQuery.of(context);
      // Out of the way while typing, on screens it would cover, or with nothing to show.
      if (!c.showButton || media.viewInsets.bottom > 0) {
        if (_pulse.isAnimating) _pulse.stop();
        return const SizedBox.shrink();
      }
      final screen = media.size;
      const s = ActivityBubble.size;
      // The touch area: the button and room for its ring.
      const box = s + 12;
      const margin = 4.0;
      final top = media.padding.top + 8;
      final bottom = screen.height - media.padding.bottom - box - 8;
      final x = _drag?.dx ?? (c.onRight ? screen.width - box - margin : margin);
      final y = (_drag?.dy ?? c.heightShare * screen.height).clamp(top, bottom);
      final needs = c.needsYou;
      final total = c.items.length;
      if (needs > 0 && !_pulse.isAnimating) _pulse.repeat();
      if (needs == 0 && _pulse.isAnimating) _pulse.stop();
      final theme = Theme.of(context);

      return Positioned(
        left: x,
        top: y,
        child: GestureDetector(
          onPanStart: (_) => setState(() => _drag = Offset(x, y)),
          onPanUpdate: (d) => setState(() => _drag = (_drag ?? Offset(x, y)) + d.delta),
          onPanEnd: (_) {
            final pos = _drag ?? Offset(x, y);
            // Settle on the nearest side, at the height it was dropped.
            c.savePosition(pos.dx + box / 2 > screen.width / 2, pos.dy.clamp(top, bottom) / screen.height);
            setState(() => _drag = null);
          },
          onTap: ActivitySheet.show,
          child: Semantics(
            button: true,
            label: needs > 0 ? 'act_bubble_needs'.trParams({'count': '$needs'}) : 'act_bubble'.trParams({'count': '$total'}),
            child: SizedBox(
              width: box,
              height: box,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                // A soft ring that grows and fades while something needs them.
                if (needs > 0)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: s + 12 * _pulse.value,
                      height: s + 12 * _pulse.value,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.primaryColor.withValues(alpha: 0.35 * (1 - _pulse.value))),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _drag != null ? theme.primaryColor.withValues(alpha: 0.85) : theme.primaryColor,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 27),
                ),
                if (needs > 0 || total > 0) Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: needs > 0 ? const Color(0xFFE02020) : const Color(0xFF3F3F46),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text('${needs > 0 ? needs : total}', style: textBold.copyWith(fontSize: 11, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

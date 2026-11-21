import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/dashboard/domain/models/navigation_model.dart';
import 'package:ride_sharing_user_app/features/notification/controllers/notification_controller.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride's bottom navigation.
///
/// A light floating dock with every tab labelled, a brand-red active state,
/// and a raised E-Ride button in the middle that opens the quick-book sheet
/// (ride / parcel / schedule) from anywhere in the app. The button is the one
/// thing on the dock that is not a tab, which is why it is raised out of it.
///
/// Everything animates off one duration so it can be zeroed for users who
/// have asked the OS to remove animations.
class ERideNavDock extends StatelessWidget {
  final List<NavigationModel> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onBookTap;

  const ERideNavDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onBookTap,
  });

  static const double height = 66;
  static const double _bookSize = 60;
  /// How far the book button rises above the dock's top edge.
  static const double _bookLift = 24;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Duration duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 260);
    final Color accent = Theme.of(context).primaryColor;
    final bool dark = Get.isDarkMode;
    final int half = items.length ~/ 2;

    Widget tab(int i) => Expanded(
          child: _DockItem(
            item: items[i],
            selected: i == currentIndex,
            duration: duration,
            onTap: () => onSelect(i),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSize,
      ),
      child: SizedBox(
        height: height + _bookLift,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0, right: 0, bottom: 0, height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: dark ? 0.25 : 0.14)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.5 : 0.14), blurRadius: 26, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(children: [
                for (int i = 0; i < half; i++) tab(i),
                // The centre slot is owned by the raised book button.
                SizedBox(width: _bookSize + 12, child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      'book'.tr,
                      style: textSemiBold.copyWith(fontSize: 10, color: accent),
                    ),
                  ),
                )),
                for (int i = half; i < items.length; i++) tab(i),
              ]),
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: Center(child: _BookButton(accent: accent, size: _bookSize, onTap: onBookTap)),
          ),
        ]),
      ),
    );
  }
}

/// The raised E-Ride button: brand mark on red, with a card-coloured ring so
/// it reads as cut out of the dock rather than sitting on it.
class _BookButton extends StatelessWidget {
  final Color accent;
  final double size;
  final VoidCallback onTap;
  const _BookButton({required this.accent, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'book'.tr,
      child: Container(
        width: size + 10,
        height: size + 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).cardColor),
        padding: const EdgeInsets.all(5),
        child: Material(
          color: accent,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: Image.asset(Images.brandMarkOnDark, height: 26, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final NavigationModel item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _DockItem({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final Color idle = Theme.of(context).hintColor;

    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Active marker: a short red dash above the icon
          AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            width: selected ? 18 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          AnimatedScale(
            scale: selected ? 1.0 : 0.92,
            duration: duration,
            curve: Curves.easeOutBack,
            // The shipped icons are white monochrome PNGs, so they take any tint.
            child: item.unreadBadge
                ? GetBuilder<NotificationController>(builder: (n) => Badge(
                    isLabelVisible: n.unreadTotal > 0,
                    label: Text(n.unreadTotal > 99 ? '99+' : '${n.unreadTotal}'),
                    child: Image.asset(selected ? item.activeIcon : item.inactiveIcon, width: 22, height: 22, color: selected ? accent : idle),
                  ))
                : Image.asset(
                    selected ? item.activeIcon : item.inactiveIcon,
                    width: 22,
                    height: 22,
                    color: selected ? accent : idle,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (selected ? textSemiBold : textMedium).copyWith(
              fontSize: 10,
              color: selected ? accent : idle,
            ),
          ),
        ]),
      ),
    );
  }
}

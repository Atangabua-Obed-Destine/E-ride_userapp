import 'package:ride_sharing_user_app/common_widgets/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One row inside a profile section card: icon in a soft tile, title,
/// chevron. `danger` rows (logout, delete) are drawn in the error colour and
/// without a chevron, since they open a confirmation rather than a screen.
class ProfileMenuItem extends StatelessWidget {
  final String title;
  final String icon;
  final Function()? onTap;
  final bool divider;
  final bool danger;
  final int badge;
  const ProfileMenuItem({super.key, required this.title, required this.icon, this.onTap, this.divider = true, this.danger = false, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final Color tone = danger ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor;
    final Color text = danger
        ? Theme.of(context).colorScheme.error
        : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);

    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize, vertical: Dimensions.paddingSize),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
              child: Center(child: Image.asset(icon, width: 18, height: 18, fit: BoxFit.contain, color: tone)),
            ),
            const SizedBox(width: Dimensions.paddingSize),

            Expanded(child: Text(
              title.tr,
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: text),
            )),

            CountPill(count: badge),
            if (!danger) Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
          ]),
        ),
      ),

      if (divider)
        Divider(height: 1, thickness: 1, indent: 60, color: Theme.of(context).hintColor.withValues(alpha: 0.12)),
    ]);
  }
}

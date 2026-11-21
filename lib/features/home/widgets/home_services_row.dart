import 'package:flutter/material.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Section title used by every block on the home screen: a short red route
/// dash, the title, and an optional trailing widget (a count pill, a link).
class HomeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const HomeSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSize,
      ),
      child: Row(children: [
        Container(
          width: 4, height: 18,
          margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: textBold.copyWith(
              fontSize: Dimensions.fontSizeLarge,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

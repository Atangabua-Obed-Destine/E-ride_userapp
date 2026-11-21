import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/features/guide/controllers/guide_controller.dart';
import 'package:ride_sharing_user_app/features/guide/domain/models/guide_models.dart';
import 'package:ride_sharing_user_app/features/guide/widgets/guide_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Every tour of the city the person is in.
class ToursScreen extends StatelessWidget {
  const ToursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: GetBuilder<GuideController>(builder: (g) {
        final List<TourCard> tours = g.tours;
        return BodyWidget(
          appBar: AppBarWidget(title: g.city != null ? 'guide_tours_in'.trParams({'city': g.city!}) : 'guide_tours'.tr, showBackButton: true),
          body: RefreshIndicator(
            color: theme.primaryColor,
            onRefresh: () => g.loadHome(force: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, 100),
              children: [
                Text('guide_tours_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                const SizedBox(height: Dimensions.paddingSize),
                if (tours.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Text('guide_no_tours'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.hintColor)),
                  )
                else
                  for (final TourCard t in tours) ...[
                    LayoutBuilder(builder: (_, c) => TourCardWidget(tour: t, width: c.maxWidth)),
                    if (t.intro != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                        child: Text(t.intro!, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
                      ),
                    const SizedBox(height: Dimensions.paddingSizeLarge),
                  ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

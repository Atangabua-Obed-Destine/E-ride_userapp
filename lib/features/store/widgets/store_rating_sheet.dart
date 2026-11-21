import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/store/domain/models/store_order_model.dart';
import 'package:ride_sharing_user_app/features/store/widgets/store_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

const Color _starAmber = Color(0xFFF5A623);

/// "How was your order?": the food (required) and the rider (optional), in
/// one sheet. Opens by itself once on a delivered order, or from the card.
class StoreRatingSheet extends StatefulWidget {
  final StoreOrderModel order;
  final int initialStoreRating;
  const StoreRatingSheet({super.key, required this.order, this.initialStoreRating = 0});

  static Future<void> show(StoreOrderModel order, {int initialStoreRating = 0}) {
    return Get.bottomSheet(
      StoreRatingSheet(order: order, initialStoreRating: initialStoreRating),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<StoreRatingSheet> createState() => _StoreRatingSheetState();
}

class _StoreRatingSheetState extends State<StoreRatingSheet> {
  late int _store = widget.initialStoreRating;
  int _rider = 0;
  final TextEditingController _storeComment = TextEditingController();
  final TextEditingController _riderComment = TextEditingController();

  @override
  void dispose() {
    _storeComment.dispose();
    _riderComment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool ok = await Get.find<StoreController>().submitReview(
      widget.order.id,
      storeRating: _store,
      storeComment: _storeComment.text,
      riderRating: _rider > 0 ? _rider : null,
      riderComment: _rider > 0 ? _riderComment.text : null,
    );
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StoreOrderModel o = widget.order;
    // Riders are rated like drivers after a ride: only when the admin lets
    // customers review drivers (Business Setup > Customer > Customer review).
    final bool driverReviewsOn = Get.find<ConfigController>().config?.reviewStatus ?? false;
    final String? rider = driverReviewsOn ? o.riderFirstName : null;
    // No keyboard padding here: Get's bottom sheet already lifts above it.
    return Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 10, Dimensions.paddingSizeLarge, Dimensions.paddingSizeDefault),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text('rate_your_order'.tr, textAlign: TextAlign.center,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 4),
              Text('rate_order_subtitle'.tr, textAlign: TextAlign.center,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              const SizedBox(height: Dimensions.paddingSizeLarge),

              _Section(
                leading: StoreLogo(url: o.storeLogo, size: 40),
                title: 'rate_food_from'.trParams({'store': o.storeName ?? ''}),
                rating: _store,
                onRate: (v) => setState(() => _store = v),
                comment: _storeComment,
                hint: 'rate_food_hint'.tr,
              ),

              if (rider != null) ...[
                Divider(height: Dimensions.paddingSizeExtraLarge * 1.4, color: theme.hintColor.withValues(alpha: 0.15)),
                _Section(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.delivery_dining_rounded, color: theme.primaryColor),
                  ),
                  title: 'rate_your_rider'.trParams({'name': rider}),
                  rating: _rider,
                  onRate: (v) => setState(() => _rider = v),
                  comment: _riderComment,
                  hint: 'rate_rider_hint'.tr,
                ),
              ],

              const SizedBox(height: Dimensions.paddingSizeLarge),
              GetBuilder<StoreController>(builder: (c) => FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge)),
                ),
                onPressed: _store == 0 || c.reviewing ? null : _submit,
                child: c.reviewing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_store == 0 ? 'tap_a_star_to_rate'.tr : 'submit_rating'.tr, style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge)),
              )),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('not_now'.tr, style: textMedium.copyWith(color: theme.hintColor)),
              ),
            ]),
          ),
        ),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget leading;
  final String title;
  final int rating;
  final ValueChanged<int> onRate;
  final TextEditingController comment;
  final String hint;
  const _Section({required this.leading, required this.title, required this.rating, required this.onRate, required this.comment, required this.hint});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        leading,
        const SizedBox(width: Dimensions.paddingSize),
        Expanded(child: Text(title, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
      ]),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      StarPicker(rating: rating, onRate: onRate),
      SizedBox(
        height: 20,
        child: Text(rating == 0 ? '' : 'rating_label_$rating'.tr, textAlign: TextAlign.center,
            style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: rating >= 4 ? const Color(0xFF12A150) : theme.hintColor)),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: rating == 0 ? const SizedBox(width: double.infinity) : Padding(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
          child: TextField(
            controller: comment,
            maxLength: 300,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: theme.hintColor.withValues(alpha: 0.07),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Five large stars; tapping one sets the rating.
class StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRate;
  final double size;
  const StarPicker({super.key, required this.rating, required this.onRate, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 1; i <= 5; i++)
        Semantics(
          button: true,
          selected: i <= rating,
          label: '$i ${'stars'.tr}',
          child: InkResponse(
            radius: size * 0.6,
            onTap: () {
              HapticFeedback.selectionClick();
              onRate(i);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size,
                  color: i <= rating ? _starAmber : Theme.of(context).hintColor.withValues(alpha: 0.45)),
            ),
          ),
        ),
    ]);
  }
}

/// Read-only stars, for a rating already given.
class StarsView extends StatelessWidget {
  final int rating;
  final double size;
  const StarsView({super.key, required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating ${'stars'.tr}',
      child: ExcludeSemantics(child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 1; i <= 5; i++)
          Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: size,
              color: i <= rating ? _starAmber : Theme.of(context).hintColor.withValues(alpha: 0.4)),
      ])),
    );
  }
}

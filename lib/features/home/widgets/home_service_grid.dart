import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/store/controllers/store_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_controller.dart';
import 'package:ride_sharing_user_app/features/home/controllers/category_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/jobs_home_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_home_screen.dart';
import 'package:ride_sharing_user_app/features/parcel/screens/parcel_screen.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/features/set_destination/screens/set_destination_screen.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/explore/screens/explore_screen.dart';
import 'package:ride_sharing_user_app/features/store/screens/store_list_screen.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "What do you need today?": every E-Ride service on one screen, no sideways
/// scrolling. Ride and Food & Shops get the two large tiles; Parcel, Hotels
/// and Schedule share the row below. Services the admin switched off drop out
/// and the rest fill the space.
class HomeServiceGrid extends StatelessWidget {
  const HomeServiceGrid({super.key});

  /// Tile backgrounds per service. Light tints of the illustration colours,
  /// darkened over the card colour in dark mode.
  static const Color _foodTint = Color(0xFFFFEFD6);
  static const Color _parcelTint = Color(0xFFF2EADC);
  static const Color _exploreTint = Color(0xFFE6EEF7);
  static const Color _scheduleTint = Color(0xFFEFEFF3);
  static const Color _moveTint = Color(0xFFFDE7E4);
  static const Color _marketTint = Color(0xFFE5F4EA);
  static const Color _jobsTint = Color(0xFFE8EEFC);

  @override
  Widget build(BuildContext context) {
    final config = Get.find<ConfigController>().config;
    final bool canOrder = config?.storeOrderingStatus ?? false;
    final bool canExplore = config?.exploreStatus ?? config?.stayStatus ?? false;
    final bool canSchedule = config?.scheduleTripStatus ?? false;
    final bool canMove = config?.moveStatus ?? false;
    final bool canMarket = config?.marketStatus ?? false;
    final bool canJobs = config?.jobsStatus ?? false;
    final String foodLabel = (config?.storeServiceLabel?.isNotEmpty ?? false) ? config!.storeServiceLabel! : 'food_and_shops'.tr;
    final String exploreLabel = (config?.exploreLabel?.isNotEmpty ?? false) ? config!.exploreLabel! : 'explore_bamenda'.tr;

    final _Service ride = _Service(
      title: 'home_ride_title'.tr,
      subtitle: null, // filled from the cheapest fare below
      image: Images.rideTile,
      tint: null,
      onTap: () => Get.to(() => const SetDestinationScreen()),
    );
    final _Service parcel = _Service(
      title: 'parcel'.tr, subtitle: 'home_parcel_sub'.tr, image: Images.parcelTile, tint: _parcelTint,
      onTap: () => Get.to(() => const ParcelScreen()),
    );
    final _Service? food = canOrder ? _Service(
      title: foodLabel, subtitle: 'home_food_sub'.tr, image: Images.foodTile, tint: _foodTint,
      onTap: () async {
        await Get.to(() => const StoreListScreen());
        Get.find<StoreController>().loadAttention();
      },
      attention: (tile) => _Attention(
        load: () => Get.find<StoreController>().loadAttention(),
        child: GetBuilder<StoreController>(builder: (s) => _Counted(count: s.toRate, right: true, child: tile)),
      ),
    ) : null;
    final _Service? explore = canExplore ? _Service(
      title: exploreLabel, subtitle: 'home_explore_sub'.tr, image: Images.exploreTile, tint: _exploreTint,
      onTap: () async {
        await Get.to(() => const ExploreScreen());
        Get.find<ListingController>().loadMeta(force: true);
      },
      // Homes lives in Explore: its count shows here.
      attention: (tile) => _Attention(
        load: () => Get.find<ListingController>().loadMeta(force: true),
        child: GetBuilder<ListingController>(builder: (l) => _Counted(count: l.meta?.attention ?? 0, child: tile)),
      ),
    ) : null;
    final _Service? schedule = canSchedule ? _Service(
      title: 'home_schedule_title'.tr, subtitle: 'home_schedule_sub'.tr, image: Images.scheduleTile, tint: _scheduleTint,
      onTap: () => Get.to(() => const SetDestinationScreen(rideType: RideType.scheduleRide)),
    ) : null;

    final _Service? move = canMove ? _Service(
      title: 'home_move_title'.tr, subtitle: 'home_move_sub'.tr, image: Images.moveTile, tint: _moveTint,
      onTap: () => Get.to(() => const SetDestinationScreen(move: true)),
    ) : null;

    final _Service? market = canMarket ? _Service(
      title: 'market'.tr, subtitle: 'home_market_sub'.tr, image: null, icon: Icons.storefront_rounded, tint: _marketTint,
      onTap: () async {
        await Get.to(() => const MarketHomeScreen());
        Get.find<MarketController>().loadMeta(force: true);
      },
      attention: (tile) => _Attention(
        load: () => Get.find<MarketController>().loadMeta(force: true),
        child: GetBuilder<MarketController>(builder: (m) => _Counted(count: m.meta?.attention ?? 0, child: tile)),
      ),
    ) : null;

    final _Service? jobs = canJobs ? _Service(
      title: 'jobs_title'.tr, subtitle: 'home_jobs_sub'.tr, image: null, icon: Icons.work_outline_rounded, tint: _jobsTint,
      onTap: () async {
        await Get.to(() => const JobsHomeScreen());
        Get.find<JobsController>().loadMeta(force: true);
      },
      attention: (tile) => _Attention(
        load: () => Get.find<JobsController>().loadMeta(force: true),
        child: GetBuilder<JobsController>(builder: (j) => _Counted(count: j.meta?.attention ?? 0, child: tile)),
      ),
    ) : null;

    // Second large tile: food when it is on, otherwise parcel moves up.
    final _Service second = food ?? parcel;
    final List<_Service> small = [if (food != null) parcel, if (market != null) market, if (jobs != null) jobs, if (move != null) move, if (explore != null) explore, if (schedule != null) schedule];
    // At most three small tiles side by side; a fourth starts a second row.
    final List<List<_Service>> smallRows = [
      for (int i = 0; i < small.length; i += 3) small.sublist(i, i + 3 > small.length ? small.length : i + 3),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      child: Column(children: [
        SizedBox(
          height: 172,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: GetBuilder<CategoryController>(builder: (categories) => _BigTile(
              service: ride.withSubtitle(_fromFare(categories) ?? 'home_ride_sub'.tr),
              primary: true,
            ))),
            const SizedBox(width: Dimensions.paddingSize),
            Expanded(child: second.attention != null ? second.attention!(_BigTile(service: second)) : _BigTile(service: second)),
          ]),
        ),
        for (final List<_Service> row in smallRows) ...[
          const SizedBox(height: Dimensions.paddingSize),
          SizedBox(
            height: 124,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (int i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: Dimensions.paddingSize),
                Expanded(child: row[i].attention != null
                    ? row[i].attention!(_SmallTile(service: row[i], wide: row.length == 1))
                    : _SmallTile(service: row[i], wide: row.length == 1)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  /// "from FCFA 100": the cheapest base fare across ride categories.
  static String? _fromFare(CategoryController controller) {
    final List<double> fares = [
      for (final category in controller.categoryList ?? [])
        if ((category.fare?.isNotEmpty ?? false) && category.fare!.first.baseFare != null) category.fare!.first.baseFare!,
    ];
    if (fares.isEmpty) return null;
    fares.sort();
    return '${'from'.tr} ${PriceConverter.convertPrice(fares.first)}';
  }
}

class _Service {
  final String title;
  final String? subtitle;
  /// The illustration; services without one yet show [icon].
  final String? image;
  final IconData? icon;
  final Color? tint;
  final VoidCallback onTap;
  /// A live count of what needs the person here (Market, Jobs, Homes in Explore, Food & Shops); none for the others.
  final Widget Function(Widget tile)? attention;
  const _Service({required this.title, required this.subtitle, required this.image, this.icon, required this.tint, required this.onTap,
      this.attention});

  _Service withSubtitle(String value) =>
      _Service(title: title, subtitle: value, image: image, icon: icon, tint: tint, onTap: onTap, attention: attention);
}

Color _background(BuildContext context, Color tint) {
  final ThemeData theme = Theme.of(context);
  return Get.isDarkMode ? Color.alphaBlend(tint.withValues(alpha: 0.10), theme.cardColor) : tint;
}

/// Large tile: title and subtitle top left, illustration bottom right, an
/// arrow to say "tap me". The ride tile is solid E-Ride red.
class _BigTile extends StatelessWidget {
  final _Service service;
  final bool primary;
  const _BigTile({required this.service, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color text = primary ? Colors.white : (theme.textTheme.bodyLarge?.color ?? Colors.black);
    final Color sub = primary ? Colors.white.withValues(alpha: 0.85) : theme.hintColor;
    return Semantics(
      button: true,
      label: '${service.title}, ${service.subtitle ?? ''}',
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        color: primary ? theme.primaryColor : _background(context, service.tint ?? theme.cardColor),
        child: InkWell(
          onTap: service.onTap,
          child: Ink(
            decoration: primary
                ? BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.primaryColor, Color.lerp(theme.primaryColor, Colors.black, 0.28)!],
                  ))
                : null,
            child: Stack(children: [
              Positioned(
                right: -6, bottom: 4,
                width: 118, height: 96,
                child: ExcludeSemantics(child: service.image != null
                    ? Image.asset(service.image!, fit: BoxFit.contain, alignment: Alignment.bottomRight)
                    : Align(alignment: Alignment.bottomRight, child: Icon(service.icon, size: 64, color: text.withValues(alpha: 0.8)))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(service.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeTwenty, color: text, height: 1.15)),
                  const SizedBox(height: 4),
                  if (service.subtitle != null)
                    Text(service.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: sub)),
                  const Spacer(),
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary ? Colors.white : theme.cardColor,
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 20, color: primary ? theme.primaryColor : text),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small tile: illustration on top, title and subtitle under it.
/// Loads a feature's counts once the tile shows (Home stays mounted), and again when the app comes back.
class _Attention extends StatefulWidget {
  final Future<void> Function() load;
  final Widget child;
  const _Attention({required this.load, required this.child});

  @override
  State<_Attention> createState() => _AttentionState();
}

class _AttentionState extends State<_Attention> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.load();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A tile with a red count in its corner: something needs the person there.
class _Counted extends StatelessWidget {
  final int count;
  final Widget child;
  /// Top right, for the big tiles whose title sits top left.
  final bool right;
  const _Counted({required this.count, required this.child, this.right = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(child: child),
      Positioned(
        top: right ? 12 : 8,
        left: right ? null : 10,
        right: right ? 12 : null,
        child: Semantics(
          label: 'home_needs_you'.trParams({'n': '$count'}),
          child: Container(
            constraints: const BoxConstraints(minWidth: 22),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Theme.of(context).cardColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(count > 99 ? '99+' : '$count', style: textBold.copyWith(fontSize: 11, color: Colors.white)),
          ),
        ),
      ),
    ]);
  }
}

class _SmallTile extends StatelessWidget {
  final _Service service;
  final bool wide;
  const _SmallTile({required this.service, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${service.title}, ${service.subtitle ?? ''}',
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: _background(context, service.tint ?? theme.cardColor),
        child: InkWell(
          onTap: service.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Align(
                alignment: Alignment.centerRight,
                child: ExcludeSemantics(child: service.image != null
                    ? Image.asset(service.image!, fit: BoxFit.contain)
                    : Icon(service.icon, size: 46, color: const Color(0xFF15803D))),
              )),
              const SizedBox(height: 6),
              Text(service.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
              if (service.subtitle != null)
                Text(service.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
            ]),
          ),
        ),
      ),
    );
  }
}

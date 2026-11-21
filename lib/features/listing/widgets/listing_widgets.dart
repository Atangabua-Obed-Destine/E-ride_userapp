import 'package:ride_sharing_user_app/helper/image_size_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

const Color listingVerifiedGreen = Color(0xFF1E9E5A);
const Color listingAmber = Color(0xFFE59A12);

/// Words shared by every Homes & spaces screen.
class ListingText {
  static String type(String type) => 'listing_type_$type'.tr;
  static String window(String window) => 'listing_window_$window'.tr;
  static String rent(Listing l) => '${PriceConverter.convertPrice(l.rent)} / ${l.rentPeriod == 'year' ? 'listing_per_year'.tr : 'listing_per_month'.tr}';
  static String day(DateTime? d) {
    if (d == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  /// "Confirmed available today", "3 days ago"...
  static String confirmed(DateTime? at) {
    if (at == null) return '';
    final int days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'listing_confirmed_today'.tr;
    if (days == 1) return 'listing_confirmed_yesterday'.tr;
    return 'listing_confirmed_days_ago'.trParams({'days': '$days'});
  }

  static String distance(int metres) => metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';

  /// About 80 m a minute on foot.
  static String walk(int metres) => 'listing_walk_minutes'.trParams({'minutes': '${(metres / 80).ceil()}'});

  static String status(String status) => 'listing_status_$status'.tr;
  static String visitStatus(String status) => 'listing_visit_status_$status'.tr;
}

/// Verified, Listed, or Not confirmed recently.
class ListingBadge extends StatelessWidget {
  final Listing listing;
  final bool compact;
  const ListingBadge({super.key, required this.listing, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color color, IconData icon, String label) = listing.verified
        ? (listingVerifiedGreen, Icons.verified_rounded, 'listing_badge_verified'.tr)
        : listing.notConfirmedRecently
            ? (listingAmber, Icons.schedule_rounded, 'listing_badge_not_confirmed'.tr)
            : (theme.hintColor, Icons.fact_check_outlined, 'listing_badge_listed'.tr);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 13 : 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: textMedium.copyWith(fontSize: compact ? Dimensions.fontSizeExtraSmall : Dimensions.fontSizeSmall, color: color)),
      ]),
    );
  }
}

class ListingPhotoBox extends StatelessWidget {
  final String? url;
  final double? height;
  final BorderRadius radius;
  const ListingPhotoBox({super.key, this.url, this.height, this.radius = const BorderRadius.all(Radius.circular(12))});

  @override
  Widget build(BuildContext context) {
    final Color tint = Theme.of(context).hintColor.withValues(alpha: 0.12);
    final Widget empty = Container(height: height, color: tint, alignment: Alignment.center,
        child: Icon(Icons.home_rounded, size: 34, color: Theme.of(context).hintColor.withValues(alpha: 0.5)));
    return ClipRRect(
      borderRadius: radius,
      child: url == null
          ? empty
          : CachedNetworkImage(imageUrl: url!, height: height, width: double.infinity, fit: BoxFit.cover,
              memCacheWidth: ImageSizeHelper.decodeWidth(context, null, height),
              placeholder: (_, __) => empty, errorWidget: (_, __, ___) => empty),
    );
  }
}

/// A listing in the search results.
class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;
  const ListingCard({super.key, required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ListingPhotoBox(url: listing.cover, height: 170, radius: const BorderRadius.vertical(top: Radius.circular(16))),
            Positioned(left: 10, top: 10, child: Container(
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
              child: ListingBadge(listing: listing, compact: true),
            )),
          ]),
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 2),
              Text('${ListingText.type(listing.type)} · ${listing.neighbourhood}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              if (listing.amenities.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSizeSmall),
                ListingAmenityPills(amenities: listing.amenities, max: 3),
              ],
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Row(children: [
                Expanded(child: Text(ListingText.rent(listing),
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor))),
                if (listing.landmarkDistanceM != null && listing.landmarkName != null)
                  Flexible(child: Text('${ListingText.distance(listing.landmarkDistanceM!)} ${'listing_from'.tr} ${listing.landmarkName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor))),
              ]),
              if (listing.confirmedAt != null) ...[
                const SizedBox(height: 4),
                Text(ListingText.confirmed(listing.confirmedAt),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall,
                        color: listing.notConfirmedRecently ? listingAmber : theme.hintColor)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A rounded bottom sheet with a title and a body.
class ListingSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const ListingSheet({super.key, required this.title, this.subtitle, required this.children});

  static Future<T?> show<T>(Widget sheet) => Get.bottomSheet<T>(sheet, isScrollControlled: true, backgroundColor: Colors.transparent);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault,
          Dimensions.paddingSizeDefault + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        const SizedBox(height: Dimensions.paddingSizeDefault),
        ...children,
      ])),
    );
  }
}

/// A row of selectable chips.
class ListingChoice extends StatelessWidget {
  final List<String> values;
  final String? selected;
  final String Function(String) label;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  const ListingChoice({super.key, required this.values, required this.selected, required this.label, required this.onChanged, this.allowNone = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: selected == v,
          showCheckmark: false,
          onSelected: (on) => onChanged(on ? v : (allowNone ? null : v)),
          selectedColor: theme.primaryColor,
          backgroundColor: theme.hintColor.withValues(alpha: 0.08),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: selected == v ? Colors.white : theme.textTheme.bodyMedium?.color),
        ),
    ]);
  }
}

/// The extras an owner can tick (backend Listing::AMENITIES), with their icons.
class ListingAmenity {
  static const Map<String, IconData> icons = {
    'wifi': Icons.wifi_rounded,
    'cctv': Icons.videocam_rounded,
    'water_tank': Icons.water_drop_rounded,
    'parking': Icons.local_parking_rounded,
    'tarred_road': Icons.add_road_rounded,
    'tiled_floor': Icons.grid_view_rounded,
    'wardrobe': Icons.checkroom_rounded,
    'study_area': Icons.menu_book_rounded,
    'hot_water': Icons.hot_tub_rounded,
    'laundry_area': Icons.local_laundry_service_rounded,
    'cleaning': Icons.cleaning_services_rounded,
    'air_conditioning': Icons.ac_unit_rounded,
  };

  /// The server's list (so one can be withdrawn without an app update), keeping only those this app has words for.
  static List<String> all(ListingMeta? meta) {
    final List<String> known = (meta?.amenities ?? const <String>[]).where(icons.containsKey).toList();
    return known.isNotEmpty ? known : icons.keys.toList();
  }
  static String label(String key) => 'listing_amenity_$key'.tr;
  static IconData icon(String key) => icons[key] ?? Icons.check_circle_outline_rounded;
}

/// Tick several extras.
class ListingAmenityPicker extends StatelessWidget {
  final List<String> values;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const ListingAmenityPicker({super.key, required this.values, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: [
      for (final v in values)
        FilterChip(
          avatar: Icon(ListingAmenity.icon(v), size: 16, color: selected.contains(v) ? Colors.white : theme.hintColor),
          label: Text(ListingAmenity.label(v)),
          selected: selected.contains(v),
          showCheckmark: false,
          onSelected: (on) => onChanged(on ? [...selected, v] : selected.where((s) => s != v).toList()),
          selectedColor: theme.primaryColor,
          backgroundColor: theme.hintColor.withValues(alpha: 0.08),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall,
              color: selected.contains(v) ? Colors.white : theme.textTheme.bodyMedium?.color),
        ),
    ]);
  }
}

/// A listing's extras as small icon pills.
class ListingAmenityPills extends StatelessWidget {
  final List<String> amenities;
  final int? max;
  const ListingAmenityPills({super.key, required this.amenities, this.max});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> known = amenities.where(ListingAmenity.icons.containsKey).toList();
    final List<String> shown = max == null ? known : known.take(max!).toList();
    final int more = known.length - shown.length;
    Widget pill(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(20)),
          child: child,
        );
    final TextStyle style = textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.textTheme.bodyMedium?.color);
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final a in shown)
        pill(Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ListingAmenity.icon(a), size: 14, color: theme.primaryColor),
          const SizedBox(width: 4),
          Text(ListingAmenity.label(a), style: style),
        ])),
      if (more > 0) pill(Text('+$more', style: style)),
    ]);
  }
}

class ListingSectionTitle extends StatelessWidget {
  final String text;
  const ListingSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault, bottom: Dimensions.paddingSizeSmall),
        child: Text(text, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).textTheme.bodyLarge?.color)),
      );
}

// ------------------------------------------------------------------ sheets

/// Search filters.
class ListingFilterSheet extends StatefulWidget {
  const ListingFilterSheet({super.key});

  @override
  State<ListingFilterSheet> createState() => _ListingFilterSheetState();
}

class _ListingFilterSheetState extends State<ListingFilterSheet> {
  late ListingFilters f = Get.find<ListingController>().filters;
  late final TextEditingController rent = TextEditingController(text: f.maxRent?.round().toString() ?? '');

  @override
  void dispose() {
    rent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ListingMeta? meta = Get.find<ListingController>().meta;
    return ListingSheet(title: 'listing_filters'.tr, children: [
      Text('listing_what'.tr, style: textMedium),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ListingChoice(values: meta?.types ?? const [], selected: f.type, label: ListingText.type, allowNone: true,
          onChanged: (v) => setState(() => f = f.copyWith(type: v, clearType: v == null))),
      const ListingSectionTitle(''),
      Text('listing_where'.tr, style: textMedium),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ListingChoice(values: meta?.neighbourhoods ?? const [], selected: f.neighbourhood, label: (v) => v, allowNone: true,
          onChanged: (v) => setState(() => f = f.copyWith(neighbourhood: v, clearArea: v == null))),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      TextField(
        controller: rent,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'listing_max_rent_month'.tr, border: const OutlineInputBorder()),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: f.verifiedOnly, title: Text('listing_verified_only'.tr),
          onChanged: (v) => setState(() => f = f.copyWith(verifiedOnly: v))),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: f.water, title: Text('listing_has_water'.tr),
          onChanged: (v) => setState(() => f = f.copyWith(water: v))),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: f.backupPower, title: Text('listing_has_backup_power'.tr),
          onChanged: (v) => setState(() => f = f.copyWith(backupPower: v))),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      Text('listing_must_have'.tr, style: textMedium),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      ListingAmenityPicker(values: ListingAmenity.all(meta), selected: f.amenities,
          onChanged: (v) => setState(() => f = f.copyWith(amenities: v))),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      Row(children: [
        Expanded(child: ButtonWidget(buttonText: 'listing_clear'.tr, transparent: true, showBorder: true, onPressed: () {
          Get.back();
          Get.find<ListingController>().setFilters(const ListingFilters());
        })),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(child: ButtonWidget(buttonText: 'listing_show_results'.tr, onPressed: () {
          final double? max = double.tryParse(rent.text.trim());
          Get.back();
          Get.find<ListingController>().setFilters(f.copyWith(maxRent: max, clearRent: max == null));
        })),
      ]),
    ]);
  }
}

/// Book a visit: a day in the next 30, and a time of day.
class BookVisitSheet extends StatefulWidget {
  final Listing listing;
  final bool propose; // the owner proposing another time for a visit
  final String? visitId;
  const BookVisitSheet({super.key, required this.listing, this.propose = false, this.visitId});

  @override
  State<BookVisitSheet> createState() => _BookVisitSheetState();
}

class _BookVisitSheetState extends State<BookVisitSheet> {
  DateTime? day;
  String window = 'morning';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime today = DateTime.now();
    final List<DateTime> days = [for (int i = 0; i < 14; i++) DateTime(today.year, today.month, today.day + i)];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return GetBuilder<ListingController>(builder: (c) => ListingSheet(
      title: widget.propose ? 'listing_propose_time'.tr : 'listing_book_visit'.tr,
      subtitle: widget.propose ? null : 'listing_book_visit_hint'.tr,
      children: [
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: Dimensions.paddingSizeSmall),
            itemBuilder: (_, i) {
              final DateTime d = days[i];
              final bool on = day == d;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => day = d),
                child: Container(
                  width: 58,
                  decoration: BoxDecoration(
                    color: on ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(i == 0 ? 'listing_today'.tr : weekdays[d.weekday - 1],
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: on ? Colors.white : theme.hintColor)),
                    Text('${d.day}', style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: on ? Colors.white : theme.textTheme.bodyLarge?.color)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        ListingChoice(values: c.meta?.windows ?? const ['morning', 'afternoon', 'evening'], selected: window,
            label: ListingText.window, onChanged: (v) => setState(() => window = v ?? window)),
        const SizedBox(height: Dimensions.paddingSizeLarge),
        ButtonWidget(
          buttonText: widget.propose ? 'listing_send_proposal'.tr : 'listing_ask_for_visit'.tr,
          onPressed: day == null || c.saving ? null : () async {
            final bool ok = widget.propose
                ? await c.ownerRespond(widget.visitId!, 'propose', date: day, window: window)
                : await c.book(widget.listing.id, day!, window);
            if (ok && context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    ));
  }
}

/// Report a listing.
class ReportListingSheet extends StatefulWidget {
  final String listingId;
  const ReportListingSheet({super.key, required this.listingId});

  @override
  State<ReportListingSheet> createState() => _ReportListingSheetState();
}

class _ReportListingSheetState extends State<ReportListingSheet> {
  String? reason;
  final TextEditingController note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ListingController>(builder: (c) => ListingSheet(
      title: 'listing_report'.tr,
      subtitle: 'listing_report_hint'.tr,
      children: [
        for (final r in (c.meta?.reportReasons ?? const <String>[]).where((r) => r != 'no_show'))
          ListingOption(selected: reason == r, label: 'listing_reason_$r'.tr, onTap: () => setState(() => reason = r)),
        TextField(controller: note, maxLines: 3, maxLength: 500,
            decoration: InputDecoration(hintText: 'listing_report_note'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ButtonWidget(buttonText: 'listing_send_report'.tr, onPressed: reason == null || c.saving ? null : () async {
          if (await c.report(widget.listingId, reason!, note.text.trim()) && context.mounted) Navigator.of(context).pop();
        }),
      ],
    ));
  }
}

/// How the visit went.
class VisitOutcomeSheet extends StatefulWidget {
  final ListingVisit visit;
  const VisitOutcomeSheet({super.key, required this.visit});

  @override
  State<VisitOutcomeSheet> createState() => _VisitOutcomeSheetState();
}

class _VisitOutcomeSheetState extends State<VisitOutcomeSheet> {
  String? outcome;
  final TextEditingController note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ListingController>(builder: (c) => ListingSheet(
      title: 'listing_how_was_visit'.tr,
      subtitle: 'listing_how_was_visit_hint'.tr,
      children: [
        for (final o in const ['as_described', 'not_as_described', 'taken', 'no_show'])
          ListingOption(selected: outcome == o, label: 'listing_outcome_$o'.tr, onTap: () => setState(() => outcome = o)),
        if (outcome != null && outcome != 'as_described')
          TextField(controller: note, maxLines: 2, maxLength: 500,
              decoration: InputDecoration(hintText: 'listing_report_note'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ButtonWidget(buttonText: 'listing_send'.tr, onPressed: outcome == null || c.saving ? null : () async {
          if (await c.outcome(widget.visit.id, outcome!, note.text.trim()) && context.mounted) Navigator.of(context).pop();
        }),
      ],
    ));
  }
}

/// One choice in a list where only one can be picked.
class ListingOption extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  const ListingOption({super.key, required this.selected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? Theme.of(context).primaryColor : Theme.of(context).hintColor),
        title: Text(label),
        onTap: onTap,
      );
}

/// A short yes or no question before an action that cannot be undone.
Future<bool> listingConfirm(String title, String body, String yes) async {
  final bool? ok = await Get.dialog<bool>(AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: Text('listing_cancel'.tr)),
      TextButton(onPressed: () => Get.back(result: true), child: Text(yes)),
    ],
  ));
  return ok == true;
}

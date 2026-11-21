import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/explore/domain/models/explore_place_model.dart';
import 'package:ride_sharing_user_app/features/explore/screens/explore_screen.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The Explore Bamenda categories as a looping carousel: one category large in
/// the centre, its neighbours smaller and faded on each side. It moves on by
/// itself every few seconds, pauses while the customer touches it, and stays
/// still when the phone asks for reduced motion.
///
/// Tapping the centre card opens that category; tapping a side card brings it
/// to the centre.
class ExploreCarousel extends StatefulWidget {
  final List<ExploreCategory> categories;
  const ExploreCarousel({super.key, required this.categories});

  static const double height = 176;

  @override
  State<ExploreCarousel> createState() => _ExploreCarouselState();
}

class _ExploreCarouselState extends State<ExploreCarousel> {
  static const Duration _interval = Duration(seconds: 4);
  static const Duration _resumeAfter = Duration(seconds: 8);
  static const double _viewport = 0.52;

  // Starts far from 0 so the loop works both ways without ever hitting an end.
  late final PageController _pages = PageController(
    viewportFraction: _viewport,
    initialPage: widget.categories.length * 500,
  );
  Timer? _autoplay;
  Timer? _resume;
  int _current = 0;

  int get _count => widget.categories.length;

  @override
  void initState() {
    super.initState();
    _current = _pages.initialPage;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _resume?.cancel();
    _pages.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _start() {
    _autoplay?.cancel();
    if (!mounted || _count < 2 || _reduceMotion) return;
    _autoplay = Timer.periodic(_interval, (_) {
      if (!mounted || !_pages.hasClients) return;
      _pages.nextPage(duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  /// The customer is touching the carousel: stop, then carry on later.
  void _pause() {
    _autoplay?.cancel();
    _resume?.cancel();
    _resume = Timer(_resumeAfter, _start);
  }

  void _tap(int index, ExploreCategory category) {
    if (index == _current) {
      ExploreCategoryTile.open(category);
    } else {
      _pause();
      _pages.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(children: [
      SizedBox(
        height: ExploreCarousel.height,
        child: NotificationListener<UserScrollNotification>(
          onNotification: (n) {
            if (n.direction != ScrollDirection.idle) _pause();
            return false;
          },
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final ExploreCategory category = widget.categories[index % _count];
              return AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  // 0 at the centre, 1 one card away. Before layout, use the page index.
                  final double page = _pages.hasClients && _pages.position.haveDimensions ? (_pages.page ?? _current.toDouble()) : _current.toDouble();
                  final double distance = (page - index).abs().clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: 1 - distance * 0.18,
                    child: Opacity(opacity: 1 - distance * 0.45, child: child),
                  );
                },
                child: _CarouselCard(
                  category: category,
                  selected: index == _current,
                  onTap: () => _tap(index, category),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeSmall),
      // Where we are in the loop.
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < _count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _current % _count ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _current % _count
                  ? ExploreIcons.color(widget.categories[i].icon)
                  : theme.hintColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    ]);
  }
}

class _CarouselCard extends StatelessWidget {
  final ExploreCategory category;
  final bool selected;
  final VoidCallback onTap;
  const _CarouselCard({required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color tint = ExploreIcons.color(category.icon);
    final Color deep = Color.lerp(tint, Colors.black, 0.35)!;
    final String tagKey = 'explore_tag_${category.key}';
    final String tag = tagKey.tr == tagKey ? 'explore_tag_default'.tr : tagKey.tr;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Semantics(
        button: true,
        label: '${category.name}. $tag',
        child: Material(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          elevation: selected ? 6 : 0,
          shadowColor: tint.withValues(alpha: 0.5),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [tint, deep]),
              ),
              child: Stack(children: [
                // A large, faint copy of the icon as texture.
                Positioned(
                  right: -18, bottom: -22,
                  child: Icon(ExploreIcons.icon(category.icon), size: 120, color: Colors.white.withValues(alpha: 0.13)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(14)),
                      child: Icon(ExploreIcons.icon(category.icon), color: Colors.white, size: 26),
                    ),
                    const Spacer(),
                    Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: textBold.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeLarge, height: 1.15)),
                    const SizedBox(height: 2),
                    Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: Dimensions.fontSizeSmall)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

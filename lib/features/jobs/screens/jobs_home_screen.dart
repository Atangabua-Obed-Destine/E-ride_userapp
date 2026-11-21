import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/employer_setup_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/job_alerts_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/job_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_applications_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_jobs_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/work_card_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride Jobs: verified jobs near you, the Work Card, and "Hiring?" for employers.
class JobsHomeScreen extends StatefulWidget {
  const JobsHomeScreen({super.key});

  @override
  State<JobsHomeScreen> createState() => _JobsHomeScreenState();
}

class _JobsHomeScreenState extends State<JobsHomeScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  JobsController get _jobs => Get.find<JobsController>();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _jobs.loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search.text = _jobs.query;
      _jobs.loadMeta(force: true);
      _jobs.loadFeed();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([_jobs.loadMeta(force: true), _jobs.loadFeed()]);
  }

  void _hiring() {
    final employer = _jobs.meta?.employer;
    Get.to(() => employer == null ? const EmployerSetupScreen() : const MyJobsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          Text('E-Ride ', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.primaryColor)),
          Text('jobs_title'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
        ]),
        actions: [
          GetBuilder<JobsController>(builder: (j) => IconButton(
            tooltip: 'jobs_alerts'.tr,
            onPressed: () => Get.to(() => const JobAlertsScreen()),
            icon: Icon(j.meta?.alertOn ?? false ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
          )),
          GetBuilder<JobsController>(builder: (j) {
            final unread = j.meta?.nextStepsUnread ?? 0;
            return IconButton(
              tooltip: 'jobs_my_applications'.tr,
              onPressed: () => Get.to(() => const MyApplicationsScreen()),
              icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.assignment_outlined)),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: MarketChips(child: GetBuilder<JobsController>(builder: (j) {
        final meta = j.meta;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(controller: _scroll, slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 12, Dimensions.paddingSizeDefault, 6),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: j.setQuery,
                decoration: InputDecoration(
                  hintText: 'jobs_search_hint'.tr,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: j.query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () {
                          _search.clear();
                          j.setQuery('');
                        })
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            )),
            SliverToBoxAdapter(child: SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault), children: [
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                  avatar: const Icon(Icons.bookmark_outline_rounded),
                  label: Text('jobs_saved'.tr),
                  selected: j.savedOnly,
                  showCheckmark: false,
                  onSelected: j.setSavedOnly,
                )),
                for (final t in meta?.types ?? const ['full_time', 'part_time', 'day_job', 'internship'])
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                    label: Text(jobType(t)),
                    selected: j.type == t,
                    showCheckmark: false,
                    onSelected: (_) => j.setType(t),
                  )),
              ]),
            )),
            SliverToBoxAdapter(child: SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault), children: [
                for (final c in meta?.categories ?? const [])
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                    avatar: Icon(jobCategoryIcon(c)),
                    label: Text(jobCategory(c)),
                    selected: j.category == c,
                    showCheckmark: false,
                    onSelected: (_) => j.setCategory(c),
                  )),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 6, Dimensions.paddingSizeDefault, 0),
              child: Column(children: [
                if (meta != null && meta.cardPercent < 100) _Banner(
                  icon: Icons.badge_outlined,
                  title: meta.cardPercent == 0 ? 'jobs_card_make'.tr : 'jobs_card_percent'.trParams({'n': '${meta.cardPercent}'}),
                  body: 'jobs_card_why'.tr,
                  progress: meta.cardPercent / 100,
                  onTap: () => Get.to(() => const WorkCardScreen()),
                ),
                _Banner(
                  icon: Icons.storefront_outlined,
                  title: meta?.employer == null ? 'jobs_hiring'.tr : 'jobs_my_jobs'.tr,
                  body: meta?.employer == null ? 'jobs_hiring_body'.tr
                      : ((meta?.newApplicants ?? 0) > 0 ? 'jobs_new_applicants_n'.trParams({'n': '${meta!.newApplicants}'}) : 'jobs_my_jobs_body'.tr),
                  badge: meta?.newApplicants ?? 0,
                  onTap: _hiring,
                ),
              ]),
            )),
            if (j.feedLoading && j.feed.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (j.feed.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: MarketEmpty(
                  icon: Icons.work_outline_rounded,
                  title: j.hasFilters ? 'jobs_none_match'.tr : 'jobs_none_yet'.tr,
                  body: j.hasFilters ? null : 'jobs_none_yet_body'.tr,
                  action: j.hasFilters ? 'jobs_clear_filters'.tr : 'jobs_set_alert'.tr,
                  onAction: j.hasFilters
                      ? () {
                          _search.clear();
                          j.clearFilters();
                        }
                      : () => Get.to(() => const JobAlertsScreen()),
                ),
              ))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 40),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i == j.feed.length) {
                      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                    }
                    final job = j.feed[i];
                    return JobCard(job: job, onTap: () async {
                      await Get.to(() => JobScreen(code: job.code, initial: job));
                    });
                  },
                  childCount: j.feed.length + (j.hasMore ? 1 : 0),
                )),
              ),
          ]),
        );
      })),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final double? progress;
  final int badge;
  final VoidCallback onTap;
  const _Banner({required this.icon, required this.title, required this.body, this.progress, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon, color: theme.primaryColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                const SizedBox(height: 2),
                Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.3)),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                    value: progress, minHeight: 5, backgroundColor: theme.hintColor.withValues(alpha: 0.15), color: theme.primaryColor)),
                ],
              ])),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ]),
          ),
        ),
      ),
    );
  }
}

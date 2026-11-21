import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_employer_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/applicants_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/employer_setup_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/post_job_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The employer's side: the check, "Post a job", and every job with its applicants.
class MyJobsScreen extends StatefulWidget {
  /// Just sent the employer check: say what happens next.
  final bool justSetUp;
  const MyJobsScreen({super.key, this.justSetUp = false});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  JobsEmployerController get _c => Get.find<JobsEmployerController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([_c.loadEmployer(), _c.loadMyJobs()]);
  }

  Future<void> _close(JobPost job) async {
    final yes = await Get.dialog<bool>(AlertDialog(
      title: Text('jobs_close_q'.trParams({'job': job.title})),
      content: Text('jobs_close_body'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('jobs_keep_open'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('jobs_close'.tr)),
      ],
    ));
    if (yes == true && await _c.closeJob(job.code)) showCustomSnackBar('jobs_closed_done'.tr, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
        title: Text('jobs_my_jobs'.tr),
        actions: [
          IconButton(tooltip: 'jobs_emp_edit'.tr, icon: const Icon(Icons.storefront_outlined), onPressed: () async {
            await Get.to(() => const EmployerSetupScreen());
            _refresh();
          }),
        ],
      ),
      body: GetBuilder<JobsEmployerController>(builder: (c) {
        final e = c.employer;
        final open = c.myJobs.where((j) => [JobPost.review, JobPost.live, JobPost.sentBack, JobPost.hidden].contains(j.status)).toList();
        final past = c.myJobs.where((j) => !open.contains(j)).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            if (e != null) _EmployerCard(employer: e, justSetUp: widget.justSetUp),
            const SizedBox(height: 12),
            if (e != null && e.status != JobEmployer.frozen)
              SizedBox(height: 52, child: FilledButton.icon(
                onPressed: () async {
                  await Get.to(() => const PostJobScreen());
                  _c.loadMyJobs();
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('jobs_post_a_job'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
              )),
            const SizedBox(height: 16),
            if (!c.jobsLoaded && c.jobsLoading)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (c.myJobs.isEmpty)
              SizedBox(height: 260, child: MarketEmpty(icon: Icons.work_outline_rounded, title: 'jobs_no_jobs_yet'.tr, body: 'jobs_no_jobs_yet_body'.tr))
            else ...[
              for (final j in open) _JobRow(job: j, onClose: () => _close(j), onChanged: _c.loadMyJobs),
              if (past.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                    child: Text('jobs_past_jobs'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
                for (final j in past) _JobRow(job: j, onClose: null, onChanged: _c.loadMyJobs),
              ],
            ],
            const SizedBox(height: 40),
          ]),
        );
      }),
    );
  }
}

class _EmployerCard extends StatelessWidget {
  final JobEmployer employer;
  final bool justSetUp;
  const _EmployerCard({required this.employer, required this.justSetUp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final (Color bg, Color fg, IconData icon, String title, String body) = switch (employer.status) {
      JobEmployer.verified => (jobGreenBg, jobGreen, Icons.verified_rounded, 'jobs_emp_st_verified'.tr, 'jobs_emp_st_verified_b'.tr),
      JobEmployer.rejected => (jobRedBg, jobRed, Icons.error_outline_rounded, 'jobs_emp_st_refused'.tr, employer.reviewNote ?? ''),
      JobEmployer.frozen => (jobRedBg, jobRed, Icons.block_rounded, 'jobs_emp_st_frozen'.tr, employer.reviewNote ?? ''),
      _ => (jobAmberBg, jobAmber, Icons.hourglass_top_rounded, justSetUp ? 'jobs_emp_st_sent'.tr : 'jobs_emp_st_pending'.tr, 'jobs_emp_st_pending_b'.tr),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          JobLogo(employer: employer, size: 44),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(employer.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            Text([employer.isPrivate ? 'jobs_emp_home'.tr : 'jobs_emp_business'.tr, if (employer.area != null) employer.area!].join(' · '),
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ])),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: textSemiBold.copyWith(color: fg)),
              if (body.isNotEmpty) Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.35)),
            ])),
          ]),
        ),
      ]),
    );
  }
}

class _JobRow extends StatelessWidget {
  final JobPost job;
  final VoidCallback? onClose;
  final VoidCallback onChanged;
  const _JobRow({required this.job, required this.onClose, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final look = jobPostLook(job);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: job.newApplications > 0 ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.15), width: job.newApplications > 0 ? 1.5 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
            JobTag(text: look.label, bg: look.bg, fg: look.fg),
          ]),
          const SizedBox(height: 4),
          Text(jobPay(job), style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
          const SizedBox(height: 4),
          Text([
            (job.applications == 1 ? 'jobs_one_application' : 'jobs_n_applications').trParams({'n': '${job.applications}'}),
            if (job.newApplications > 0) 'jobs_n_new'.trParams({'n': '${job.newApplications}'}),
            if (job.status == JobPost.live) (job.views == 1 ? 'jobs_one_view' : 'jobs_n_views').trParams({'n': '${job.views}'}),
            if (job.alerted > 0) 'jobs_n_alerted'.trParams({'n': '${job.alerted}'}),
          ].join(' · '), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          if (job.status == JobPost.sentBack && job.reviewNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: jobRedBg, borderRadius: BorderRadius.circular(10)),
              child: Text('jobs_post_sent_back'.trParams({'note': job.reviewNote!}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobRed, height: 1.35)),
            ),
          ],
          if (job.status == JobPost.review) ...[
            const SizedBox(height: 6),
            Text('jobs_in_review_note'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobAmber)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (job.applications > 0 || job.status == JobPost.live)
              FilledButton.icon(
                onPressed: () => Get.to(() => ApplicantsScreen(code: job.code, title: job.title)),
                icon: Badge(isLabelVisible: job.newApplications > 0, label: Text('${job.newApplications}'), child: const Icon(Icons.people_alt_outlined, size: 18)),
                label: Text('jobs_applicants'.tr),
              ),
            if (job.status == JobPost.live)
              OutlinedButton.icon(onPressed: () => shareMarketLink(job.link, '${job.title} · ${jobPay(job)}'),
                  icon: const Icon(Icons.share_outlined, size: 18), label: Text('market_share'.tr)),
            if ([JobPost.review, JobPost.sentBack, JobPost.live].contains(job.status))
              OutlinedButton.icon(
                onPressed: () async {
                  await Get.to(() => PostJobScreen(job: job));
                  onChanged();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(job.status == JobPost.sentBack ? 'jobs_fix'.tr : 'jobs_edit'.tr),
              ),
            if (onClose != null)
              TextButton(onPressed: onClose, child: Text('jobs_close'.tr, style: textMedium.copyWith(color: theme.colorScheme.error))),
          ]),
        ]),
      ),
    );
  }
}

/// Sent to E-Ride for a check: what happens next, and sharing once it is live.
class JobSentScreen extends StatelessWidget {
  final JobPost job;
  final bool edited;
  const JobSentScreen({super.key, required this.job, this.edited = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hours = Get.find<JobsController>().meta?.reviewHours ?? 2;
    final verified = Get.find<JobsEmployerController>().employer?.isVerified ?? false;
    Widget step(IconData icon, String title, String body, bool done) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: done ? jobGreen : theme.hintColor),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: textSemiBold.copyWith(color: textColor)),
              Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35)),
            ])),
          ]),
        );
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeLarge), children: [
        const Icon(Icons.task_alt_rounded, size: 64, color: jobGreen),
        const SizedBox(height: 12),
        Text(edited ? 'jobs_sent_again'.tr : 'jobs_sent_title'.tr, textAlign: TextAlign.center,
            style: textBold.copyWith(fontSize: Dimensions.fontSizeOverLarge, color: textColor)),
        const SizedBox(height: 6),
        Text('jobs_sent_body'.trParams({'job': job.title, 'n': '$hours'}), textAlign: TextAlign.center,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.hintColor, height: 1.4)),
        const SizedBox(height: 24),
        step(Icons.check_circle_rounded, 'jobs_sent_s1'.tr, 'jobs_sent_s1_b'.tr, true),
        if (!verified) step(Icons.verified_outlined, 'jobs_sent_s0'.tr, 'jobs_sent_s0_b'.tr, false),
        step(Icons.fact_check_outlined, 'jobs_sent_s2'.tr, 'jobs_sent_s2_b'.tr, false),
        step(Icons.campaign_outlined, 'jobs_sent_s3'.tr, 'jobs_sent_s3_b'.tr, false),
        step(Icons.people_alt_outlined, 'jobs_sent_s4'.tr, 'jobs_sent_s4_b'.tr, false),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
        child: SizedBox(height: 52, child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('jobs_done'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        )),
      )),
    );
  }
}

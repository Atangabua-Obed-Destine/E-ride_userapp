import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/job_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// My applications: always know where you stand (sent, seen, shortlisted, next step).
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  JobsController get _jobs => Get.find<JobsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jobs.loadApplications());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('jobs_my_applications'.tr)),
      body: GetBuilder<JobsController>(builder: (c) {
        final open = c.applications.where((a) => a.isOpen).toList()
          ..sort((a, b) => (b.nextStepUnread ? 1 : 0).compareTo(a.nextStepUnread ? 1 : 0));
        final past = c.applications.where((a) => !a.isOpen).toList();
        return RefreshIndicator(
          onRefresh: c.loadApplications,
          child: !c.applicationsLoaded && c.applicationsLoading
              ? const Center(child: CircularProgressIndicator())
              : c.applications.isEmpty
                  ? ListView(children: [SizedBox(height: 460, child: MarketEmpty(icon: Icons.assignment_outlined, title: 'jobs_no_applications'.tr,
                      body: 'jobs_no_applications_body'.tr))])
                  : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                      for (final a in open) _ApplicationRow(application: a),
                      if (past.isNotEmpty) ...[
                        Padding(padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                            child: Text('jobs_past'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor))),
                        for (final a in past) _ApplicationRow(application: a),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('jobs_stale_note'.trParams({'n': '${c.meta?.staleDays ?? 21}'}),
                            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
                      ),
                    ]),
        );
      }),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  final JobApplication application;
  const _ApplicationRow({required this.application});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final a = application;
    final look = jobApplicationLook(a);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.to(() => JobApplicationScreen(id: a.id)),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: a.nextStepUnread ? jobGreen : theme.hintColor.withValues(alpha: 0.15), width: a.nextStepUnread ? 1.5 : 1)),
            child: Opacity(
              opacity: a.isOpen ? 1 : 0.75,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  JobLogo(employer: a.job?.employer, category: a.job?.category ?? 'other', size: 40),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.job?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                    Text(a.job?.employer?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ])),
                  JobTag(text: look.label, bg: look.bg, fg: look.fg),
                ]),
                const SizedBox(height: 10),
                JobApplicationSteps(application: a),
                if (a.status == JobApplication.nextStepStatus && a.nextStep != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 16, color: jobGreen),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      a.nextStepAt != null ? 'jobs_next_step_at'.trParams({'when': jobWhen(a.nextStepAt!)}) : 'jobs_next_step_open'.tr,
                      style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobGreen),
                    )),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// One application: the steps, the employer's next step (in their words), or a kind closing note.
class JobApplicationScreen extends StatefulWidget {
  final String id;
  const JobApplicationScreen({super.key, required this.id});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  JobsController get _jobs => Get.find<JobsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jobs.loadApplication(widget.id));
  }

  Future<void> _withdraw() async {
    final yes = await Get.dialog<bool>(AlertDialog(
      title: Text('jobs_withdraw_q'.tr),
      content: Text('jobs_withdraw_body'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('jobs_keep'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('jobs_withdraw'.tr)),
      ],
    ));
    if (yes != true) return;
    if (await _jobs.withdraw(widget.id)) showCustomSnackBar('jobs_withdrawn'.tr, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<JobsController>(builder: (c) {
      final a = c.application(widget.id);
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('jobs_application'.tr)),
        body: a == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => c.loadApplication(widget.id),
                child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                  if (a.job != null)
                    Material(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Get.to(() => JobScreen(code: a.job!.code, initial: a.job)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            JobLogo(employer: a.job!.employer, category: a.job!.category, size: 44),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.job!.title, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                              Text('${a.job!.employer?.name ?? ''} · ${jobPay(a.job!)}',
                                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                            ])),
                            Icon(Icons.chevron_right_rounded, color: theme.hintColor),
                          ]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  JobApplicationSteps(application: a),
                  const SizedBox(height: 14),
                  _status(context, a),
                  JobLabel('jobs_you_sent'.tr),
                  Text(a.sentAt != null ? 'jobs_sent_on'.trParams({'when': jobWhen(a.sentAt!)}) : '',
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  const SizedBox(height: 6),
                  for (int i = 0; i < a.questions.length && i < a.answers.length; i++)
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                      Icon(a.answers[i] ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: a.answers[i] ? jobGreen : jobRed),
                      const SizedBox(width: 6),
                      Expanded(child: Text(a.questions[i], style: textRegular.copyWith(color: textColor))),
                    ])),
                  if (a.message != null)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('"${a.message}"', style: textRegular.copyWith(color: textColor, fontStyle: FontStyle.italic))),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.sharePhone ? 'jobs_phone_shared'.tr : 'jobs_phone_private'.tr,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
                  const SizedBox(height: 18),
                  const JobNoFeeNotice(),
                  if (a.isOpen && a.status != JobApplication.hired) ...[
                    const SizedBox(height: 10),
                    TextButton(onPressed: _withdraw, child: Text('jobs_withdraw'.tr, style: textMedium.copyWith(color: theme.colorScheme.error))),
                  ],
                  const SizedBox(height: 30),
                ]),
              ),
      );
    });
  }

  Widget _status(BuildContext context, JobApplication a) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final employer = a.job?.employer?.name ?? '';
    final Widget? map = a.nextStepLat != null && a.nextStepLng != null && a.isOpen
        ? Padding(padding: const EdgeInsets.only(top: 10), child: MarketMapCard(shopName: employer,
            point: MarketPoint(lat: a.nextStepLat!, lng: a.nextStepLng!, address: a.nextStepPlace)))
        : null;
    if (a.status == JobApplication.hired) {
      return Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: jobGreenBg, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.celebration_outlined, color: jobGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(a.hireConfirmed ? 'jobs_you_got_it'.trParams({'name': employer}) : 'jobs_says_you_got_it'.trParams({'name': employer}),
                  style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: jobGreen))),
            ]),
            const SizedBox(height: 6),
            Text(a.hireConfirmed ? 'jobs_you_got_it_b'.tr : 'jobs_says_you_got_it_b'.tr,
                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobGreen, height: 1.4)),
            if (a.hireToAnswer) ...[
              const SizedBox(height: 10),
              GetBuilder<JobsController>(builder: (c) => Row(children: [
                Expanded(child: FilledButton(
                  onPressed: c.saving ? null : () async {
                    if (await c.answerHire(a.id, true)) showCustomSnackBar('jobs_congrats'.tr, isError: false);
                  },
                  style: FilledButton.styleFrom(backgroundColor: jobGreen),
                  child: Text('jobs_yes_i_got_it'.tr),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: c.saving ? null : () => c.answerHire(a.id, false),
                  child: Text('jobs_no_i_did_not'.tr),
                )),
              ])),
            ],
          ]),
        ),
        if (map != null) map,
      ]);
    }
    if (a.status == JobApplication.nextStepStatus && a.nextStep != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: jobGreenBg, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.mark_email_read_outlined, color: jobGreen),
            const SizedBox(width: 8),
            Expanded(child: Text('jobs_next_step_from'.trParams({'name': employer}), style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: jobGreen))),
          ]),
          if (a.nextStepAt != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.event_rounded, size: 18, color: jobGreen),
              const SizedBox(width: 8),
              Text(jobWhen(a.nextStepAt!), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
            ]),
          ],
          if (a.nextStepPlace != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.place_outlined, size: 18, color: jobGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(a.nextStepPlace!, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
            ]),
          ],
          const SizedBox(height: 10),
          Text(a.nextStep!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.45)),
          const SizedBox(height: 10),
          Text('jobs_next_step_note'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobGreen, height: 1.4)),
          if (map != null) map,
        ]),
      );
    }
    final (String title, String body, Color bg, Color fg) = switch (a.status) {
      JobApplication.sent => ('jobs_s_sent_t'.tr, 'jobs_s_sent_b'.trParams({'name': employer}), const Color(0xFFF1F3F3), const Color(0xFF48615E)),
      JobApplication.seen => ('jobs_s_seen_t'.trParams({'name': employer}), 'jobs_s_seen_b'.tr, jobBlueBg, jobBlue),
      JobApplication.shortlisted => ('jobs_s_short_t'.tr, 'jobs_s_short_b'.trParams({'name': employer}), jobAmberBg, jobAmber),
      JobApplication.notSelected => ('jobs_s_not_t'.tr, a.employerNote ?? 'jobs_s_not_b'.trParams({'name': employer}), const Color(0xFFF1F3F3), const Color(0xFF48615E)),
      JobApplication.withdrawn => ('jobs_s_withdrawn_t'.tr, 'jobs_s_withdrawn_b'.tr, const Color(0xFFF1F3F3), const Color(0xFF48615E)),
      _ => ('jobs_s_closed_t'.tr, a.closedReason == 'no_answer' ? 'jobs_s_noanswer_b'.tr : 'jobs_s_closed_b'.tr, const Color(0xFFF1F3F3), const Color(0xFF48615E)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: fg)),
        const SizedBox(height: 4),
        Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.4)),
      ]),
    );
  }
}

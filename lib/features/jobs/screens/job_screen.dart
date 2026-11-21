import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/applicants_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_applications_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/work_card_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_posted_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_map_card.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One job: the pay, the hours, the place and the way there, what is needed, and one-tap apply.
class JobScreen extends StatefulWidget {
  final String code;
  final JobPost? initial;
  const JobScreen({super.key, required this.code, this.initial});

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  JobsController get _jobs => Get.find<JobsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jobs.loadJob(widget.code));
  }

  Future<void> _apply(JobPost job) async {
    var card = _jobs.card;
    if (!_jobs.cardLoaded) card = await _jobs.loadCard();
    if (card == null || !card.canApply) {
      final done = await Get.to<bool>(() => const WorkCardScreen(forApply: true));
      if (done != true) return;
      card = _jobs.card;
      if (card == null || !card.canApply) return;
    }
    var missing = job.requiredLinks.where((t) => !card!.hasLink(t)).toList();
    if (missing.isNotEmpty) {
      final add = await Get.dialog<bool>(AlertDialog(
        title: Text('jobs_links_needed_t'.tr),
        content: Text('jobs_links_needed_b'.trParams({'links': missing.map(jobLinkLabel).join(', ')})),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('jobs_cancel'.tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text('jobs_links_add'.tr)),
        ],
      ));
      if (add != true) return;
      await Get.to(() => const WorkCardScreen());
      card = _jobs.card;
      missing = job.requiredLinks.where((t) => !(card?.hasLink(t) ?? false)).toList();
      if (card == null || missing.isNotEmpty) return;
    }
    final application = await Get.bottomSheet<JobApplication>(_ApplySheet(job: job, card: card), isScrollControlled: true,
        backgroundColor: Get.theme.cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    if (application != null) {
      showCustomSnackBar('jobs_applied_done'.trParams({'employer': job.employer?.name ?? ''}), isError: false);
    }
  }

  Future<void> _report(JobPost job) async {
    final reasons = _jobs.meta?.reportReasons ?? const JobsMeta().reportReasons;
    final sent = await Get.bottomSheet<bool>(_ReportSheet(code: job.code, reasons: reasons), isScrollControlled: true,
        backgroundColor: Get.theme.cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    if (sent == true) showCustomSnackBar('jobs_reported'.tr, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<JobsController>(builder: (c) {
      final job = c.job(widget.code) ?? widget.initial;
      if (job == null) {
        return Scaffold(
          appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent),
          body: c.isGone(widget.code)
              ? MarketEmpty(icon: Icons.work_off_outlined, title: 'jobs_gone'.tr)
              : const Center(child: CircularProgressIndicator()),
        );
      }
      final full = c.job(widget.code) != null;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(tooltip: 'market_share'.tr, icon: const Icon(Icons.share_outlined), onPressed: () => shareMarketLink(job.link, '${job.title} · ${jobPay(job)}')),
            if (!job.mine)
              IconButton(
                tooltip: 'jobs_save'.tr,
                icon: Icon(job.saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, color: job.saved ? theme.primaryColor : null),
                onPressed: full ? () => c.toggleSave(job.code) : null,
              ),
            if (!job.mine)
              PopupMenuButton<String>(
                color: theme.cardColor,
                onSelected: (_) => _report(job),
                itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text('jobs_report'.tr))],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => c.loadJob(widget.code),
          child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              JobLogo(employer: job.employer, category: job.category, size: 56),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor, height: 1.2)),
                const SizedBox(height: 2),
                Text(job.employer?.name ?? '', style: textMedium.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                Text([if (job.liveAt != null) 'jobs_posted_ago'.trParams({'ago': jobAgo(job.liveAt)}),
                  if (job.applications > 0) 'jobs_n_applied'.trParams({'n': '${job.applications}'})].join(' · '),
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (job.employer?.isVerified ?? false) const JobVerifiedTag(),
              if (job.employer?.isPrivate ?? false) JobTag(text: 'jobs_private_employer'.tr, bg: jobPrivateBg, fg: jobPrivateFg),
              JobTag(text: jobType(job.type)),
              JobTag(text: jobCategory(job.category), icon: jobCategoryIcon(job.category)),
              JobTag(text: job.places == 1 ? 'jobs_one_place'.tr : 'jobs_places_n'.trParams({'n': '${job.places}'})),
            ]),
            if (!job.isLive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F3F3), borderRadius: BorderRadius.circular(12)),
                child: Text(job.mine ? jobPostLook(job).label : 'jobs_closed_note'.tr, style: textMedium.copyWith(color: const Color(0xFF48615E))),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Fact(icon: Icons.payments_outlined, label: 'jobs_pay'.tr, value: jobPay(job), strong: true),
                if (job.schedule != null) _Fact(icon: Icons.schedule_rounded, label: 'jobs_hours'.tr, value: job.schedule!),
                if (job.area != null) _Fact(icon: Icons.place_outlined, label: 'jobs_where'.tr, value: job.area!),
                if (job.closesAt != null && job.isLive)
                  _Fact(icon: Icons.event_outlined, label: 'jobs_open_until'.tr, value: '${'market_wd_${job.closesAt!.weekday}'.tr} ${job.closesAt!.day} ${'market_mo_${job.closesAt!.month}'.tr}'),
              ]),
            ),
            if (job.description != null) ...[
              JobLabel('jobs_the_job'.tr),
              Text(job.description!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.45)),
            ],
            if (job.requirements != null || job.skills.isNotEmpty) ...[
              JobLabel('jobs_you_need'.tr),
              if (job.requirements != null)
                Text(job.requirements!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.45)),
              if (job.skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final s in job.skills) JobTag(text: s)]),
              ],
            ],
            if (job.questions.isNotEmpty) ...[
              JobLabel('jobs_they_ask'.tr),
              for (final q in job.questions)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.help_outline_rounded, size: 16, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text(q, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
                ])),
            ],
            if (job.requiredLinks.isNotEmpty) ...[
              JobLabel('jobs_they_want_links'.tr),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in job.requiredLinks) JobTag(text: jobLinkLabel(t), icon: jobLinkIcon(t), bg: jobBlueBg, fg: jobBlue),
              ]),
            ],
            if (job.lat != null && job.lng != null) ...[
              JobLabel('jobs_where_work'.tr),
              MarketMapCard(shopName: job.employer?.name ?? job.title, point: MarketPoint(lat: job.lat!, lng: job.lng!, address: job.address ?? job.area)),
            ],
            if (job.employer?.about != null || (job.employer?.isPrivate ?? false) || (job.employer?.hires ?? 0) > 0) ...[
              JobLabel('jobs_about_employer'.trParams({'name': job.employer?.name ?? ''})),
              if ((job.employer?.hires ?? 0) > 0)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                  const Icon(Icons.handshake_outlined, size: 18, color: jobGreen),
                  const SizedBox(width: 6),
                  Text((job.employer!.hires == 1 ? 'jobs_one_hired_here' : 'jobs_n_hired_here').trParams({'n': '${job.employer!.hires}'}),
                      style: textSemiBold.copyWith(color: jobGreen)),
                ])),
              if (job.employer?.about != null)
                Text(job.employer!.about!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor, height: 1.45)),
              if (job.employer?.isPrivate ?? false)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('jobs_private_employer_note'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobPrivateFg, height: 1.4))),
            ],
            const SizedBox(height: Dimensions.paddingSizeDefault),
            const JobNoFeeNotice(),
            const SizedBox(height: 90),
          ]),
        ),
        bottomNavigationBar: SafeArea(child: Container(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 10),
          decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))]),
          child: SizedBox(height: 52, child: _action(job, full, c)),
        )),
      );
    });
  }

  Widget _action(JobPost job, bool full, JobsController c) {
    if (job.mine) {
      return FilledButton.icon(
        onPressed: () => Get.to(() => ApplicantsScreen(code: job.code, title: job.title)),
        icon: const Icon(Icons.people_alt_outlined),
        label: Text('jobs_see_applicants_n'.trParams({'n': '${job.applications}'})),
      );
    }
    if (job.myApplicationId != null) {
      return OutlinedButton.icon(
        onPressed: () => Get.to(() => JobApplicationScreen(id: job.myApplicationId!)),
        icon: const Icon(Icons.assignment_turned_in_outlined),
        label: Text('jobs_applied_see'.tr),
      );
    }
    if (!job.isLive) {
      return FilledButton(onPressed: null, child: Text('jobs_closed'.tr));
    }
    return FilledButton.icon(
      onPressed: full && !c.saving ? () => _apply(job) : null,
      icon: const Icon(Icons.send_rounded),
      label: Text('jobs_easy_apply'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool strong;
  const _Fact({required this.icon, required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          Text(value, style: (strong ? textBold : textSemiBold).copyWith(
              fontSize: strong ? Dimensions.fontSizeLarge : Dimensions.fontSizeDefault, color: strong ? theme.primaryColor : theme.textTheme.bodyLarge?.color)),
        ])),
      ]),
    );
  }
}

/// Easy apply: the Work Card, the employer's yes-or-no questions, a word, the phone (optional), send.
class _ApplySheet extends StatefulWidget {
  final JobPost job;
  final WorkCard card;
  const _ApplySheet({required this.job, required this.card});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  late final List<bool?> _answers = List<bool?>.filled(widget.job.questions.length, null);
  final TextEditingController _message = TextEditingController();
  bool _sharePhone = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_answers.any((a) => a == null)) return showCustomSnackBar('jobs_answer_all'.tr);
    final application = await Get.find<JobsController>().apply(widget.job.code, [for (final a in _answers) a!], _message.text, _sharePhone);
    if (application != null && mounted) Navigator.of(context).pop(application);
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.textTheme.bodyLarge?.color;
        final card = widget.card;
        final summary = [
          if (card.skills.isNotEmpty) (card.skills.length == 1 ? 'jobs_one_skill' : 'jobs_n_skills').trParams({'n': '${card.skills.length}'}),
          if (card.experience.isNotEmpty) (card.experience.length == 1 ? 'jobs_one_job' : 'jobs_n_jobs').trParams({'n': '${card.experience.length}'}),
          if (card.hasCv) 'jobs_cv'.tr,
          if (card.hasVoice) 'jobs_voice_intro'.tr,
          if (card.links.isNotEmpty) (card.links.length == 1 ? 'jobs_one_link' : 'jobs_n_links').trParams({'n': '${card.links.length}'}),
        ].join(' · ');
        return Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text('jobs_apply_to'.trParams({'job': widget.job.title}), style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
            const SizedBox(height: 12),
            Material(
              color: theme.hintColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Get.to(() => const WorkCardScreen()),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    MarketShopAvatar(name: card.name, size: 40),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${card.name} · ${'jobs_work_card'.tr}', style: textSemiBold.copyWith(color: textColor)),
                      if (summary.isNotEmpty) Text(summary, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                    ])),
                    Text('jobs_edit'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  ]),
                ),
              ),
            ),
            if (widget.job.questions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('jobs_employer_asks'.trParams({'name': widget.job.employer?.name ?? ''}), style: textSemiBold.copyWith(color: textColor)),
              for (int i = 0; i < widget.job.questions.length; i++) ...[
                const SizedBox(height: 8),
                Text(widget.job.questions[i], style: textRegular.copyWith(color: textColor)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: Text('jobs_yes'.tr), selected: _answers[i] == true, showCheckmark: false, onSelected: (_) => setState(() => _answers[i] = true)),
                  ChoiceChip(label: Text('jobs_no'.tr), selected: _answers[i] == false, showCheckmark: false, onSelected: (_) => setState(() => _answers[i] = false)),
                ]),
              ],
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _message,
              maxLines: 3,
              maxLength: 600,
              decoration: jobInput(context, 'jobs_why_you'.tr),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _sharePhone,
              onChanged: (v) => setState(() => _sharePhone = v),
              title: Text('jobs_share_phone'.tr, style: textMedium.copyWith(color: textColor)),
              subtitle: Text('jobs_share_phone_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ),
            const SizedBox(height: 6),
            GetBuilder<JobsController>(builder: (c) => SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: c.saving ? null : _send,
                child: c.saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('jobs_send_application'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
              ),
            )),
          ])),
        );
      }));
}

class _ReportSheet extends StatefulWidget {
  final String code;
  final List<String> reasons;
  const _ReportSheet({required this.code, required this.reasons});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final TextEditingController _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return showCustomSnackBar('jobs_report_choose'.tr);
    setState(() => _sending = true);
    final ok = await Get.find<JobsController>().report(widget.code, _reason!, _note.text.trim());
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: (context) => _body(context)));

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text('jobs_report_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
        const SizedBox(height: 4),
        Text('jobs_report_body'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in widget.reasons)
            ChoiceChip(label: Text('jobs_report_$r'.tr), selected: _reason == r, showCheckmark: false, onSelected: (_) => setState(() => _reason = r)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 300, maxLines: 2, decoration: jobInput(context, 'jobs_report_note'.tr)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 50, child: FilledButton(
          onPressed: _sending ? null : _send,
          child: Text('jobs_report_send'.tr, style: textSemiBold.copyWith(color: Colors.white)),
        )),
      ])),
    );
  }
}

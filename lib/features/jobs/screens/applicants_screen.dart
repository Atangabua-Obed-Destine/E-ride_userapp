import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_employer_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_voice.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_point_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// The employer's applicants for one job: new, shortlisted, others. Best match first; nobody is hidden.
class ApplicantsScreen extends StatefulWidget {
  final String code;
  final String title;
  const ApplicantsScreen({super.key, required this.code, required this.title});

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  static const _tabs = ['new', 'shortlist', 'other'];

  JobsEmployerController get _c => Get.find<JobsEmployerController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([for (final t in _tabs) _c.loadApplicants(widget.code, t)]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('jobs_applicants'.tr),
            Text(widget.title, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: GetBuilder<JobsEmployerController>(builder: (c) => TabBar(tabs: [
              Tab(text: '${'jobs_tab_new'.tr} (${c.count(widget.code, 'new')})'),
              Tab(text: '${'jobs_tab_shortlist'.tr} (${c.count(widget.code, 'shortlist')})'),
              Tab(text: '${'jobs_tab_other'.tr} (${c.count(widget.code, 'other')})'),
            ])),
          ),
        ),
        body: GetBuilder<JobsEmployerController>(builder: (c) => TabBarView(children: [
          for (final t in _tabs)
            RefreshIndicator(
              onRefresh: _refresh,
              child: c.isLoading(widget.code, t) && c.applicants(widget.code, t).isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : c.applicants(widget.code, t).isEmpty
                      ? ListView(children: [SizedBox(height: 420, child: MarketEmpty(
                          icon: Icons.people_outline_rounded,
                          title: 'jobs_none_$t'.tr,
                          body: t == 'new' ? 'jobs_none_new_body'.tr : null,
                        ))])
                      : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                          if (t == 'new')
                            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('jobs_fit_explain'.tr,
                                style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4))),
                          for (final a in c.applicants(widget.code, t)) _ApplicantRow(applicant: a, onBack: _refresh),
                        ]),
            ),
        ])),
      ),
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  final JobApplicant applicant;
  final Future<void> Function() onBack;
  const _ApplicantRow({required this.applicant, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final a = applicant;
    final fit = a.fit;
    final isNew = a.status == JobApplication.sent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Get.to(() => ApplicantScreen(id: a.id));
            onBack();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isNew ? theme.primaryColor : theme.hintColor.withValues(alpha: 0.15), width: isNew ? 1.5 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                MarketShopAvatar(name: a.name, size: 42),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.name, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor)),
                  Text([if (a.area != null) a.area!, if (a.headline != null) a.headline!].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ])),
                if (fit != null && fit.of > 0)
                  JobTag(text: 'jobs_fits'.trParams({'n': '${fit.score}', 'of': '${fit.of}'}),
                      bg: fit.score == fit.of ? jobGreenBg : const Color(0xFFF1F3F3), fg: fit.score == fit.of ? jobGreen : const Color(0xFF48615E)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (isNew) JobTag(text: 'jobs_new'.tr, bg: jobRedBg, fg: jobRed),
                if (a.status == JobApplication.nextStepStatus)
                  JobTag(text: a.nextStepRead == true ? 'jobs_next_read'.tr : 'jobs_next_sent'.tr, bg: jobGreenBg, fg: jobGreen,
                      icon: a.nextStepRead == true ? Icons.done_all_rounded : Icons.done_rounded),
                if (fit != null && fit.questions > 0)
                  JobTag(text: 'jobs_yes_n'.trParams({'n': '${fit.yes}', 'of': '${fit.questions}'}),
                      bg: fit.yes == fit.questions ? jobGreenBg : jobAmberBg, fg: fit.yes == fit.questions ? jobGreen : jobAmber),
                for (final s in a.skills.take(3)) JobTag(text: s),
                if (a.status == JobApplication.hired) JobTag(text: a.hireConfirmed ? 'jobs_st_hired'.tr : 'jobs_hired_waiting'.tr, bg: jobGreenBg, fg: jobGreen,
                    icon: Icons.handshake_outlined),
                if (a.hasVoice) JobTag(text: '${a.voiceSeconds ?? 30} s', icon: Icons.mic_none_rounded, bg: const Color(0xFF1D2D2B), fg: Colors.white),
                if (a.linksCount > 0) JobTag(text: '${a.linksCount}', icon: Icons.link_rounded),
                if (a.hasCv) JobTag(text: 'jobs_cv'.tr, icon: Icons.description_outlined),
                if (a.hasMessage) JobTag(text: 'jobs_message'.tr, icon: Icons.chat_bubble_outline_rounded),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One applicant: the Work Card, answers and message, the phone if they shared it,
/// and the employer's answer: shortlist, not this time, or the next step.
class ApplicantScreen extends StatefulWidget {
  final String id;
  const ApplicantScreen({super.key, required this.id});

  @override
  State<ApplicantScreen> createState() => _ApplicantScreenState();
}

class _ApplicantScreenState extends State<ApplicantScreen> {
  JobsEmployerController get _c => Get.find<JobsEmployerController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.loadApplicant(widget.id));
  }

  Future<void> _notSelected(JobApplicant a) async {
    final note = TextEditingController();
    final go = await Get.dialog<bool>(AlertDialog(
      title: Text('jobs_not_this_time_q'.trParams({'name': a.name})),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('jobs_not_this_time_body'.tr),
        const SizedBox(height: 10),
        TextField(controller: note, maxLength: 400, maxLines: 2, decoration: jobInput(context, 'jobs_not_this_time_note'.tr)),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('jobs_cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('jobs_send'.tr)),
      ],
    ));
    if (go == true) {
      final r = await _c.act(a.id, 'not-selected', {if (note.text.trim().isNotEmpty) 'note': note.text.trim()});
      if (r != null) showCustomSnackBar('jobs_told_kindly'.tr, isError: false);
    }
    note.dispose();
  }

  /// The employer says this person got the job; if the places are now filled, offer to close the job.
  Future<void> _hire(JobApplicant a) async {
    final fills = a.jobHired + 1 >= a.jobPlaces;
    final choice = await Get.dialog<String>(AlertDialog(
      title: Text('jobs_hire_q'.trParams({'name': a.name})),
      content: Text(fills ? 'jobs_hire_body_fills'.tr : 'jobs_hire_body'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: null), child: Text('jobs_cancel'.tr)),
        if (fills) TextButton(onPressed: () => Get.back(result: 'open'), child: Text('jobs_hire_keep_open'.tr)),
        TextButton(onPressed: () => Get.back(result: fills ? 'close' : 'open'), child: Text(fills ? 'jobs_hire_and_close'.tr : 'jobs_hire_yes'.tr)),
      ],
    ));
    if (choice == null) return;
    final r = await _c.act(a.id, 'hire', {'close': choice == 'close' ? 1 : 0});
    if (r != null) {
      showCustomSnackBar('jobs_hire_sent'.trParams({'name': a.name}), isError: false);
      if (choice == 'close') _c.loadMyJobs();
    }
  }

  Future<void> _nextStep(JobApplicant a) async {
    final sent = await Get.bottomSheet<JobApplicant>(_NextStepSheet(applicant: a), isScrollControlled: true,
        backgroundColor: Get.theme.cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    if (sent != null) showCustomSnackBar('jobs_next_step_sent'.trParams({'name': a.name}), isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<JobsEmployerController>(builder: (c) {
      final a = c.applicant(widget.id);
      final card = a?.card;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
        appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text(a?.name ?? '')),
        body: a == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => c.loadApplicant(widget.id),
                child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF1D2D2B), borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        MarketShopAvatar(name: a.name, size: 50),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.name, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: Colors.white)),
                          Text([if (card?.area != null) card!.area!, if (card?.languages != null) card!.languages!].join(' · '),
                              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFFC9D1D0))),
                        ])),
                      ]),
                      const SizedBox(height: 10),
                      _StatusLine(applicant: a),
                      if (card?.headline != null) ...[
                        const SizedBox(height: 8),
                        Text(card!.headline!, style: textMedium.copyWith(color: Colors.white)),
                      ],
                      if (card?.voiceUrl != null) ...[
                        const SizedBox(height: 10),
                        JobVoicePlayer(url: card!.voiceUrl, seconds: card.voiceSeconds, onDark: true),
                      ],
                      if (card != null && card.skills.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final s in card.skills) JobTag(text: s, bg: Colors.white.withValues(alpha: 0.12), fg: Colors.white),
                        ]),
                      ],
                    ]),
                  ),
                  if (a.phone != null) ...[
                    const SizedBox(height: 10),
                    Card(child: ListTile(
                      leading: const Icon(Icons.call_outlined, color: jobGreen),
                      title: Text(a.phone!, style: textSemiBold.copyWith(color: textColor)),
                      subtitle: Text('jobs_phone_shared_by'.trParams({'name': a.name})),
                      onTap: () => launchUrl(Uri.parse('tel:${a.phone}')),
                    )),
                  ],
                  if (card != null && card.links.isNotEmpty) ...[
                    JobLabel('jobs_card_links'.tr),
                    for (final l in card.links)
                      Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
                        dense: true,
                        leading: Icon(jobLinkIcon(l.type), color: theme.primaryColor),
                        title: Text(jobLinkLabel(l.type), style: textSemiBold.copyWith(color: textColor)),
                        subtitle: Text(l.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                      )),
                  ],
                  if (a.questions.isNotEmpty) ...[
                    JobLabel('jobs_answers'.tr),
                    for (int i = 0; i < a.questions.length && i < a.answers.length; i++)
                      Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                        Icon(a.answers[i] ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: a.answers[i] ? jobGreen : jobRed),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.questions[i], style: textRegular.copyWith(color: textColor))),
                        Text(a.answers[i] ? 'jobs_yes'.tr : 'jobs_no'.tr, style: textSemiBold.copyWith(color: a.answers[i] ? jobGreen : jobRed)),
                      ])),
                  ],
                  if (a.message != null) ...[
                    JobLabel('jobs_their_message'.tr),
                    Text('"${a.message}"', style: textRegular.copyWith(color: textColor, fontStyle: FontStyle.italic, height: 1.4)),
                  ],
                  if (card != null && card.experience.isNotEmpty) ...[
                    JobLabel('jobs_card_experience'.tr),
                    for (final e in card.experience)
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.work_history_outlined, size: 18, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text([e.title, if (e.place != null) e.place!, if (e.years.isNotEmpty) e.years].join(' · '),
                            style: textRegular.copyWith(color: textColor))),
                      ])),
                  ],
                  if (card?.education != null) ...[
                    JobLabel('jobs_card_education'.tr),
                    Text(card!.education!, style: textRegular.copyWith(color: textColor)),
                  ],
                  if (card != null && card.lookingFor.isNotEmpty) ...[
                    JobLabel('jobs_card_looking_for'.tr),
                    Wrap(spacing: 6, runSpacing: 6, children: [for (final t in card.lookingFor) JobTag(text: jobType(t))]),
                  ],
                  if (card?.cvUrl != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(card!.cvUrl!), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.description_outlined),
                      label: Text('jobs_open_cv'.tr),
                    ),
                  ],
                  if (a.status == JobApplication.nextStepStatus && a.nextStep != null) ...[
                    JobLabel('jobs_next_step_you_sent'.tr),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: jobGreenBg, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (a.nextStepAt != null) Text(jobWhen(a.nextStepAt!), style: textBold.copyWith(color: jobGreen)),
                        if (a.nextStepPlace != null) Text(a.nextStepPlace!, style: textSemiBold.copyWith(color: jobGreen)),
                        const SizedBox(height: 4),
                        Text(a.nextStep!, style: textRegular.copyWith(color: textColor, height: 1.4)),
                      ]),
                    ),
                  ],
                  if (a.status == JobApplication.hired)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: jobGreenBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(a.hireConfirmed ? 'jobs_hired_confirmed_long'.trParams({'name': a.name}) : 'jobs_hired_waiting_long'.trParams({'name': a.name}),
                          style: textMedium.copyWith(color: jobGreen, height: 1.4)),
                    ),
                  if (a.status == JobApplication.notSelected)
                    Padding(padding: const EdgeInsets.only(top: 14), child: Text('jobs_marked_not_selected'.tr,
                        style: textMedium.copyWith(color: theme.hintColor))),
                  const SizedBox(height: 120),
                ]),
              ),
        bottomNavigationBar: a == null || !const [JobApplication.sent, JobApplication.seen, JobApplication.shortlisted, JobApplication.nextStepStatus].contains(a.status)
            ? null
            : SafeArea(child: Container(
                padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 10, Dimensions.paddingSizeDefault, 10),
                decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                    onPressed: c.saving ? null : () => _nextStep(a),
                    icon: const Icon(Icons.event_note_outlined),
                    label: Text(a.status == JobApplication.nextStepStatus ? 'jobs_send_new_next_step'.tr : 'jobs_send_next_step'.tr,
                        style: textSemiBold.copyWith(color: Colors.white)),
                  )),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(
                      onPressed: c.saving ? null : () => _hire(a),
                      icon: const Icon(Icons.handshake_outlined),
                      label: Text('jobs_mark_hired'.tr),
                    ))),
                    const SizedBox(width: 8),
                    if (a.status == JobApplication.sent || a.status == JobApplication.seen) ...[
                      Expanded(child: SizedBox(height: 46, child: OutlinedButton.icon(
                        onPressed: c.saving ? null : () => _c.act(a.id, 'shortlist'),
                        icon: const Icon(Icons.star_outline_rounded),
                        label: Text('jobs_shortlist'.tr),
                      ))),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: SizedBox(height: 46, child: TextButton(
                      onPressed: c.saving ? null : () => _notSelected(a),
                      child: Text('jobs_not_this_time'.tr, style: textMedium.copyWith(color: theme.hintColor)),
                    ))),
                  ]),
                ]),
              )),
      );
    });
  }
}

/// Where this applicant stands, in one line on the dark card.
class _StatusLine extends StatelessWidget {
  final JobApplicant applicant;
  const _StatusLine({required this.applicant});

  @override
  Widget build(BuildContext context) {
    final a = applicant;
    final (String text, Color fg) = switch (a.status) {
      JobApplication.shortlisted => ('jobs_st_shortlisted'.tr, const Color(0xFFFCD34D)),
      JobApplication.hired => (a.hireConfirmed ? 'jobs_hired_confirmed'.tr : 'jobs_hired_waiting'.tr, const Color(0xFF86EFAC)),
      JobApplication.nextStepStatus => (a.nextStepRead == true ? 'jobs_next_read'.tr : 'jobs_next_sent'.tr, const Color(0xFF86EFAC)),
      JobApplication.notSelected => ('jobs_st_not_selected'.tr, const Color(0xFFC9D1D0)),
      JobApplication.closed => ('jobs_st_closed'.tr, const Color(0xFFC9D1D0)),
      _ => ('jobs_st_seen'.tr, const Color(0xFF93C5FD)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg)),
    );
  }
}

/// The way forward, in the employer's words: a day and time, the place, who to ask for, what to bring.
class _NextStepSheet extends StatefulWidget {
  final JobApplicant applicant;
  const _NextStepSheet({required this.applicant});

  @override
  State<_NextStepSheet> createState() => _NextStepSheetState();
}

class _NextStepSheetState extends State<_NextStepSheet> {
  late final TextEditingController _message = TextEditingController(text: widget.applicant.nextStep ?? '');
  late final TextEditingController _place = TextEditingController(
      text: widget.applicant.nextStepPlace ?? Get.find<JobsEmployerController>().employer?.address ?? '');
  DateTime? _at;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final a = widget.applicant;
    final previous = a.nextStepAt;
    if (previous != null && previous.isAfter(DateTime.now())) _at = previous;
    // The pin: the last one sent, else the job's place, else the employer's.
    final employer = Get.find<JobsEmployerController>().employer;
    _lat = a.nextStepLat ?? a.jobLat ?? employer?.lat;
    _lng = a.nextStepLng ?? a.jobLng ?? employer?.lng;
  }

  Future<void> _pickPin() async {
    final Address? p = await pickMarketPoint(title: 'jobs_next_step_pin'.tr, hint: 'jobs_next_step_pin_hint'.tr);
    if (p?.latitude == null || !mounted) return;
    setState(() {
      _lat = p!.latitude;
      _lng = p.longitude;
      if (p.address != null && _place.text.trim().isEmpty) _place.text = p.address!;
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final day = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 60)),
        initialDate: _at ?? now.add(const Duration(days: 1)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: _at != null ? TimeOfDay.fromDateTime(_at!) : const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (at.isBefore(now)) return showCustomSnackBar('jobs_time_future'.tr);
    setState(() => _at = at);
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return showCustomSnackBar('jobs_next_step_needed'.tr);
    String two(int v) => v.toString().padLeft(2, '0');
    final r = await Get.find<JobsEmployerController>().act(widget.applicant.id, 'next-step', {
      'message': _message.text.trim(),
      if (_at != null) 'at': '${_at!.year}-${two(_at!.month)}-${two(_at!.day)} ${two(_at!.hour)}:${two(_at!.minute)}',
      if (_place.text.trim().isNotEmpty) 'place': _place.text.trim(),
      if (_lat != null && _lng != null) 'lat': _lat,
      if (_lat != null && _lng != null) 'lng': _lng,
    });
    if (r != null && mounted) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text('jobs_next_step_to'.trParams({'name': widget.applicant.name}), style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor)),
        const SizedBox(height: 4),
        Text('jobs_next_step_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusDefault), border: Border.all(color: theme.hintColor.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.event_outlined, color: theme.primaryColor),
              const SizedBox(width: 10),
              Expanded(child: Text(_at != null ? jobWhen(_at!) : 'jobs_next_step_when'.tr,
                  style: textRegular.copyWith(color: _at != null ? textColor : theme.hintColor))),
              if (_at != null)
                IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _at = null))
              else
                Text('jobs_choose'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        TextField(controller: _place, maxLength: 191, decoration: jobInput(context, 'jobs_next_step_place'.tr)),
        Row(children: [
          Icon(_lat != null ? Icons.place_rounded : Icons.place_outlined, size: 18, color: _lat != null ? jobGreen : theme.hintColor),
          const SizedBox(width: 6),
          Expanded(child: Text(_lat != null ? 'jobs_next_step_pin_on'.tr : 'jobs_next_step_pin_off'.tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
          TextButton(onPressed: _pickPin, child: Text(_lat != null ? 'jobs_change'.tr : 'jobs_choose'.tr)),
          if (_lat != null) IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() {
            _lat = null;
            _lng = null;
          })),
        ]),
        TextField(controller: _message, maxLength: 1000, maxLines: 5, minLines: 3, decoration: jobInput(context, 'jobs_next_step_message'.tr)),
        const SizedBox(height: 6),
        GetBuilder<JobsEmployerController>(builder: (c) => SizedBox(width: double.infinity, height: 52, child: FilledButton(
          onPressed: c.saving ? null : _send,
          child: c.saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('jobs_send'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      ])),
    );
  }
}

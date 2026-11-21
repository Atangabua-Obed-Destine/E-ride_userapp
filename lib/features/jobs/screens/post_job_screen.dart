import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_employer_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_jobs_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_point_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A starting point: the title, kind of work, a description, skills and questions, filled in for the employer.
class _Template {
  final String key;
  final String category;
  final String type;
  final String period;
  const _Template(this.key, this.category, {this.type = 'full_time', this.period = 'month'});
}

const List<_Template> _templates = [
  _Template('sales', 'sales'),
  _Template('cleaner', 'cleaning', type: 'part_time'),
  _Template('driver', 'driving'),
  _Template('cook', 'shop_restaurant'),
  _Template('teacher', 'teaching'),
  _Template('secretary', 'office'),
  _Template('house_help', 'cleaning'),
  _Template('helper_day', 'other', type: 'day_job', period: 'day'),
];

/// Post a job (or fix one): pay is required, then E-Ride checks it before it goes live.
class PostJobScreen extends StatefulWidget {
  final JobPost? job;
  const PostJobScreen({super.key, this.job});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _payMin = TextEditingController();
  final TextEditingController _payMax = TextEditingController();
  final TextEditingController _schedule = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _requirements = TextEditingController();
  final TextEditingController _skill = TextEditingController();
  final List<TextEditingController> _questions = [];
  final List<String> _skills = [];
  final Set<String> _requiredLinks = {};
  String? _template;
  String _category = 'sales';
  String _type = 'full_time';
  String _period = 'month';
  int _places = 1;
  Address? _place;

  JobsEmployerController get _c => Get.find<JobsEmployerController>();

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    final e = _c.employer;
    if (j != null) {
      _title.text = j.title;
      _category = j.category;
      _type = j.type;
      _period = j.payPeriod;
      _payMin.text = j.payMin.round().toString();
      if (j.payMax != null) _payMax.text = j.payMax!.round().toString();
      _schedule.text = j.schedule ?? '';
      _places = j.places;
      _area.text = j.area ?? '';
      _description.text = j.description ?? '';
      _requirements.text = j.requirements ?? '';
      _skills.addAll(j.skills);
      _requiredLinks.addAll(j.requiredLinks);
      for (final q in j.questions) {
        _questions.add(TextEditingController(text: q));
      }
      if (j.lat != null && j.lng != null) _place = Address(latitude: j.lat, longitude: j.lng, address: j.address);
    } else {
      _area.text = e?.area ?? '';
      if (e?.lat != null && e?.lng != null) _place = Address(latitude: e!.lat, longitude: e.lng, address: e.address);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _payMin, _payMax, _schedule, _area, _description, _requirements, _skill, ..._questions]) {
      c.dispose();
    }
    super.dispose();
  }

  void _useTemplate(_Template t) {
    setState(() {
      _template = t.key;
      _category = t.category;
      _type = t.type;
      _period = t.period;
      _title.text = 'jobs_tpl_${t.key}'.tr;
      _description.text = 'jobs_tpl_${t.key}_desc'.tr;
      _skills
        ..clear()
        ..addAll('jobs_tpl_${t.key}_skills'.tr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
      for (final c in _questions) {
        c.dispose();
      }
      _questions
        ..clear()
        ..addAll('jobs_tpl_${t.key}_q'.tr.split('|').map((q) => q.trim()).where((q) => q.isNotEmpty).take(3).map((q) => TextEditingController(text: q)));
    });
  }

  void _addSkill(String s) {
    final v = s.trim();
    if (v.isEmpty || _skills.length >= 8 || _skills.any((x) => x.toLowerCase() == v.toLowerCase())) return;
    setState(() => _skills.add(v));
    _skill.clear();
  }

  Future<void> _send() async {
    final min = int.tryParse(_payMin.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final max = int.tryParse(_payMax.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (_title.text.trim().length < 3) return showCustomSnackBar('jobs_post_title_needed'.tr);
    if (min <= 0) return showCustomSnackBar('jobs_post_pay_needed'.tr);
    if (max != null && max > 0 && max < min) return showCustomSnackBar('jobs_post_pay_order'.tr);
    if (_description.text.trim().length < 20) return showCustomSnackBar('jobs_post_desc_needed'.tr);
    if (_area.text.trim().isEmpty) return showCustomSnackBar('jobs_post_area_needed'.tr);
    final job = await _c.saveJob({
      'title': _title.text.trim(),
      'category': _category,
      'type': _type,
      'pay_min': min,
      'pay_max': max != null && max > min ? max : '',
      'pay_period': _period,
      'schedule': _schedule.text.trim(),
      'places': _places,
      'area_label': _area.text.trim(),
      if (_place?.latitude != null) 'lat': _place!.latitude,
      if (_place?.longitude != null) 'lng': _place!.longitude,
      if (_place?.address != null) 'address': _place!.address,
      'description': _description.text.trim(),
      'requirements': _requirements.text.trim(),
      'skills': _skills,
      'questions': [for (final q in _questions) if (q.text.trim().isNotEmpty) q.text.trim()],
      'required_links': _requiredLinks.toList(),
    }, code: widget.job?.code);
    if (job == null || !mounted) return;
    Get.find<JobsController>().loadMeta(force: true);
    Get.off(() => JobSentScreen(job: job, edited: widget.job != null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final meta = Get.find<JobsController>().meta ?? const JobsMeta();
    return MarketChips(child: Builder(builder: (context) => Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text(widget.job == null ? 'jobs_post_title'.tr : 'jobs_post_fix'.tr)),
      body: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
        if (widget.job?.status == JobPost.sentBack && widget.job?.reviewNote != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: jobRedBg, borderRadius: BorderRadius.circular(12)),
            child: Text('jobs_post_sent_back'.trParams({'note': widget.job!.reviewNote!}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobRed, height: 1.4)),
          ),
        if (widget.job == null) ...[
          JobLabel('jobs_post_start_from'.tr),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _templates)
              ChoiceChip(label: Text('jobs_tpl_${t.key}'.tr), selected: _template == t.key, showCheckmark: false, onSelected: (_) => _useTemplate(t)),
          ]),
        ],
        JobLabel('jobs_post_job_title'.tr),
        TextField(controller: _title, maxLength: 120, decoration: jobInput(context, 'jobs_post_job_title_ex'.tr)),
        JobLabel('jobs_post_kind'.tr),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in meta.categories)
            ChoiceChip(avatar: Icon(jobCategoryIcon(c)), label: Text(jobCategory(c)), selected: _category == c, showCheckmark: false,
                onSelected: (_) => setState(() => _category = c)),
        ]),
        JobLabel('jobs_post_type'.tr),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in meta.types)
            ChoiceChip(label: Text(jobType(t)), selected: _type == t, showCheckmark: false, onSelected: (_) => setState(() {
              _type = t;
              if (t == 'day_job' && _period == 'month') _period = 'day';
            })),
        ]),
        JobLabel('jobs_post_pay'.tr, hint: 'jobs_post_pay_hint'.tr),
        Row(children: [
          Expanded(child: TextField(controller: _payMin, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: jobInput(context, 'jobs_post_pay_from'.tr, suffix: 'FCFA'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _payMax, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: jobInput(context, 'jobs_post_pay_to'.tr, suffix: 'FCFA'))),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in meta.periods)
            ChoiceChip(label: Text('jobs_per_x'.trParams({'p': 'jobs_per_$p'.tr})), selected: _period == p, showCheckmark: false,
                onSelected: (_) => setState(() => _period = p)),
        ]),
        JobLabel('jobs_post_hours'.tr),
        TextField(controller: _schedule, maxLength: 120, decoration: jobInput(context, 'jobs_post_hours_ex'.tr)),
        JobLabel('jobs_post_places'.tr),
        Row(children: [
          IconButton.outlined(onPressed: _places > 1 ? () => setState(() => _places--) : null, icon: const Icon(Icons.remove_rounded)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_places', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor))),
          IconButton.outlined(onPressed: _places < 500 ? () => setState(() => _places++) : null, icon: const Icon(Icons.add_rounded)),
        ]),
        JobLabel('jobs_post_where'.tr),
        TextField(controller: _area, maxLength: 80, decoration: jobInput(context, 'jobs_emp_area_ex'.tr)),
        OutlinedButton.icon(
          onPressed: () async {
            final a = await pickMarketPoint(title: 'jobs_post_where'.tr, hint: 'jobs_post_pin_hint'.tr);
            if (a != null && mounted) setState(() => _place = a);
          },
          icon: const Icon(Icons.place_outlined),
          label: Text(_place?.address ?? 'jobs_emp_pin_choose'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        JobLabel('jobs_post_desc'.tr, hint: 'jobs_post_desc_hint'.tr),
        TextField(controller: _description, maxLength: 4000, maxLines: 6, minLines: 4, decoration: jobInput(context, 'jobs_post_desc_ex'.tr)),
        JobLabel('jobs_post_needs'.tr),
        TextField(controller: _requirements, maxLength: 600, maxLines: 3, decoration: jobInput(context, 'jobs_post_needs_ex'.tr)),
        JobLabel('jobs_post_skills'.tr, hint: 'jobs_post_skills_hint'.tr),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in _skills) InputChip(label: Text(s), onDeleted: () => setState(() => _skills.remove(s))),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _skill,
          onSubmitted: _addSkill,
          decoration: jobInput(context, 'jobs_card_add_skill'.tr).copyWith(
            suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _addSkill(_skill.text)),
          ),
        ),
        JobLabel('jobs_post_questions'.tr, hint: 'jobs_post_questions_hint'.tr),
        for (int i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _questions[i],
              maxLength: 120,
              decoration: jobInput(context, 'jobs_post_question_ex'.tr).copyWith(
                suffixIcon: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _questions.removeAt(i).dispose())),
              ),
            ),
          ),
        if (_questions.length < meta.maxQuestions)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () => setState(() => _questions.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded),
            label: Text('jobs_post_add_question'.tr),
          )),
        JobLabel('jobs_post_links'.tr, hint: 'jobs_post_links_hint'.tr),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in meta.linkTypes.where((t) => t != 'other'))
            FilterChip(
              avatar: Icon(jobLinkIcon(t)),
              label: Text(jobLinkLabel(t)),
              selected: _requiredLinks.contains(t),
              showCheckmark: false,
              onSelected: (on) => setState(() => on ? _requiredLinks.add(t) : _requiredLinks.remove(t)),
            ),
        ]),
        const SizedBox(height: 10),
        JobNoFeeNotice(text: 'jobs_post_no_fee'.tr),
        const SizedBox(height: 100),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
        child: GetBuilder<JobsEmployerController>(builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: c.saving ? null : _send,
            child: c.saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('jobs_post_send'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
          )),
          const SizedBox(height: 4),
          Text('jobs_post_review_hours'.trParams({'n': '${meta.reviewHours}'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
      )),
    )));
  }
}

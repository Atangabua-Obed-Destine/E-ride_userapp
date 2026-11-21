import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_voice.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Work Card: made once, sent with every application. No phone number on it.
/// [forApply]: opened from "Easy apply"; closes with true once it is enough to apply.
class WorkCardScreen extends StatefulWidget {
  final bool forApply;
  const WorkCardScreen({super.key, this.forApply = false});

  @override
  State<WorkCardScreen> createState() => _WorkCardScreenState();
}

class _WorkCardScreenState extends State<WorkCardScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _area = TextEditingController();
  final TextEditingController _languages = TextEditingController();
  final TextEditingController _headline = TextEditingController();
  final TextEditingController _education = TextEditingController();
  final TextEditingController _skill = TextEditingController();
  final List<String> _skills = [];
  final List<WorkExperience> _experience = [];
  final Set<String> _lookingFor = {};
  XFile? _cv;
  String? _cvName;
  bool _removeCv = false;
  final List<WorkLink> _links = [];
  XFile? _voice;
  int? _voiceSeconds;
  bool _removeVoice = false;
  bool _ready = false;
  bool _dirty = false;
  bool _saved = false;

  JobsController get _jobs => Get.find<JobsController>();

  static const List<String> _suggested = ['Sales', 'Cash handling', 'Customer care', 'Cooking', 'Cleaning', 'Driving', 'Computer', 'Excel',
    'Teaching', 'Sewing', 'Hairdressing', 'Building', 'Security', 'French', 'English'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final card = await _jobs.loadCard();
      if (!mounted) return;
      setState(() {
        _name.text = card?.name ?? _jobs.suggestedName;
        _area.text = card?.area ?? '';
        _languages.text = card?.languages ?? '';
        _headline.text = card?.headline ?? '';
        _education.text = card?.education ?? '';
        _skills.addAll(card?.skills ?? const []);
        _experience.addAll(card?.experience ?? const []);
        _lookingFor.addAll(card?.lookingFor ?? const []);
        _links.addAll(card?.links ?? const []);
        _ready = true;
      });
      for (final c in [_name, _area, _languages, _headline, _education]) {
        c.addListener(_changed);
      }
    });
  }

  /// The first edit rebuilds once, so leaving asks before dropping the changes.
  void _changed() {
    if (!_dirty) setState(() {});
  }

  @override
  void setState(VoidCallback fn) {
    if (_ready) _dirty = true;
    super.setState(fn);
  }

  Future<void> _leave() async {
    final go = await Get.dialog<bool>(AlertDialog(
      title: Text('jobs_card_discard_q'.tr),
      content: Text('jobs_card_discard_body'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('jobs_keep_editing'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('jobs_discard'.tr)),
      ],
    ));
    if (go == true && mounted) {
      _saved = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _area, _languages, _headline, _education, _skill]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSkill(String s) {
    final v = s.trim();
    if (v.isEmpty || _skills.length >= 10 || _skills.any((x) => x.toLowerCase() == v.toLowerCase())) return;
    setState(() => _skills.add(v));
    _skill.clear();
  }

  Future<void> _editExperience([int? index]) async {
    final result = await Get.bottomSheet<WorkExperience>(_ExperienceSheet(initial: index == null ? null : _experience[index]),
        isScrollControlled: true, backgroundColor: Get.theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    if (result == null) return;
    setState(() => index == null ? _experience.add(result) : _experience[index] = result);
  }

  Future<void> _editLink([int? index]) async {
    final result = await Get.bottomSheet<WorkLink>(_LinkSheet(initial: index == null ? null : _links[index],
        types: Get.find<JobsController>().meta?.linkTypes ?? const JobsMeta().linkTypes),
        isScrollControlled: true, backgroundColor: Get.theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))));
    if (result == null) return;
    setState(() {
      if (index == null) {
        _links.removeWhere((l) => l.type == result.type && result.type != 'other');
        _links.add(result);
      } else {
        _links[index] = result;
      }
    });
  }

  Future<void> _pickCv() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    final file = result?.files.single;
    if (file?.path == null) return;
    if ((file!.size) > 10 * 1024 * 1024) return showCustomSnackBar('jobs_cv_too_big'.tr);
    setState(() {
      _cv = XFile(file.path!);
      _cvName = file.name;
      _removeCv = false;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showCustomSnackBar('jobs_card_name_needed'.tr);
    if (widget.forApply && _skills.isEmpty && _experience.isEmpty) return showCustomSnackBar('jobs_card_need_more'.tr);
    final ok = await _jobs.saveCard(
      name: _name.text.trim(),
      area: _area.text.trim(),
      languages: _languages.text.trim(),
      headline: _headline.text.trim(),
      education: _education.text.trim(),
      skills: _skills,
      experience: _experience,
      lookingFor: _lookingFor.toList(),
      links: _links,
      cv: _cv,
      removeCv: _removeCv,
      voice: _voice,
      voiceSeconds: _voiceSeconds,
      removeVoice: _removeVoice,
    );
    if (!ok || !mounted) return;
    _saved = true;
    if (widget.forApply) {
      Navigator.of(context).pop(true);
    } else {
      showCustomSnackBar('jobs_card_saved'.tr, isError: false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final card = Get.find<JobsController>().card;
    final hasCv = !_removeCv && (_cv != null || (card?.hasCv ?? false));
    return PopScope(
      canPop: !_dirty || _saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: MarketChips(child: Builder(builder: (context) => Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('jobs_work_card'.tr)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: jobBlueBg, borderRadius: BorderRadius.circular(12)),
                child: Text(widget.forApply ? 'jobs_card_intro_apply'.tr : 'jobs_card_intro'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobBlue, height: 1.4)),
              ),
              JobLabel('jobs_card_name'.tr),
              TextField(controller: _name, maxLength: 80, decoration: jobInput(context, 'jobs_card_name_hint'.tr)),
              JobLabel('jobs_card_area'.tr),
              TextField(controller: _area, maxLength: 80, decoration: jobInput(context, 'jobs_card_area_hint'.tr)),
              JobLabel('jobs_card_languages'.tr),
              TextField(controller: _languages, maxLength: 80, decoration: jobInput(context, 'jobs_card_languages_hint'.tr)),
              JobLabel('jobs_card_headline'.tr, hint: 'jobs_card_headline_hint'.tr),
              TextField(controller: _headline, maxLength: 120, decoration: jobInput(context, 'jobs_card_headline_example'.tr)),
              JobLabel('jobs_card_voice'.tr, hint: 'jobs_card_voice_hint'.tr),
              JobVoiceRecorder(
                savedUrl: card?.voiceUrl,
                savedSeconds: card?.voiceSeconds,
                onRecorded: (path, seconds) => setState(() {
                  _voice = XFile(path);
                  _voiceSeconds = seconds;
                  _removeVoice = false;
                }),
                onRemove: () => setState(() {
                  _voice = null;
                  _voiceSeconds = null;
                  _removeVoice = card?.hasVoice ?? false;
                }),
              ),
              JobLabel('jobs_card_skills'.tr, hint: 'jobs_card_skills_hint'.tr),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in _skills)
                  InputChip(label: Text(s), onDeleted: () => setState(() => _skills.remove(s))),
              ]),
              const SizedBox(height: 6),
              TextField(
                controller: _skill,
                textInputAction: TextInputAction.done,
                onSubmitted: _addSkill,
                decoration: jobInput(context, 'jobs_card_add_skill'.tr).copyWith(
                  suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _addSkill(_skill.text)),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in _suggested.where((s) => !_skills.any((x) => x.toLowerCase() == s.toLowerCase())).take(10))
                  ActionChip(label: Text('+ $s'), onPressed: () => _addSkill(s)),
              ]),
              JobLabel('jobs_card_experience'.tr, hint: 'jobs_card_experience_hint'.tr),
              for (int i = 0; i < _experience.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(_experience[i].title, style: textSemiBold.copyWith(color: textColor)),
                    subtitle: Text([if (_experience[i].place != null) _experience[i].place!, if (_experience[i].years.isNotEmpty) _experience[i].years].join(' · ')),
                    onTap: () => _editExperience(i),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => setState(() => _experience.removeAt(i))),
                  ),
                ),
              if (_experience.length < 6)
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                  onPressed: () => _editExperience(),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('jobs_card_add_experience'.tr),
                )),
              JobLabel('jobs_card_links'.tr, hint: 'jobs_card_links_hint'.tr),
              for (int i = 0; i < _links.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(jobLinkIcon(_links[i].type), color: theme.primaryColor),
                    title: Text(jobLinkLabel(_links[i].type), style: textSemiBold.copyWith(color: textColor)),
                    subtitle: Text(_links[i].url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _editLink(i),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => setState(() => _links.removeAt(i))),
                  ),
                ),
              if (_links.length < 5)
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                  onPressed: () => _editLink(),
                  icon: const Icon(Icons.add_link_rounded),
                  label: Text('jobs_card_add_link'.tr),
                )),
              JobLabel('jobs_card_education'.tr),
              TextField(controller: _education, maxLength: 300, maxLines: 2, decoration: jobInput(context, 'jobs_card_education_hint'.tr)),
              JobLabel('jobs_card_looking_for'.tr),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in const ['full_time', 'part_time', 'day_job', 'internship'])
                  FilterChip(
                    label: Text(jobType(t)),
                    selected: _lookingFor.contains(t),
                    showCheckmark: false,
                    onSelected: (on) => setState(() => on ? _lookingFor.add(t) : _lookingFor.remove(t)),
                  ),
              ]),
              JobLabel('jobs_card_cv'.tr, hint: 'jobs_card_cv_hint'.tr),
              if (hasCv)
                Card(child: ListTile(
                  leading: Icon(Icons.description_outlined, color: theme.primaryColor),
                  title: Text(_cvName ?? card?.cvName ?? 'CV', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: _cv == null && card?.cvUrl != null ? Text('jobs_card_cv_open'.tr) : null,
                  onTap: _cv == null && card?.cvUrl != null
                      ? () => launchUrl(Uri.parse(card!.cvUrl!), mode: LaunchMode.externalApplication)
                      : null,
                  trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() {
                    _cv = null;
                    _cvName = null;
                    _removeCv = card?.hasCv ?? false;
                  })),
                ))
              else
                OutlinedButton.icon(onPressed: _pickCv, icon: const Icon(Icons.upload_file_rounded), label: Text('jobs_card_add_cv'.tr)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(child: Text('jobs_card_privacy'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4))),
              ]),
              const SizedBox(height: 100),
            ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
        child: GetBuilder<JobsController>(builder: (c) => SizedBox(height: 52, child: FilledButton(
          onPressed: c.saving || !_ready ? null : _save,
          child: c.saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.forApply ? 'jobs_card_save_continue'.tr : 'jobs_card_save'.tr,
                  style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      )),
    ))));
  }
}

/// One professional link: what it is (LinkedIn, GitHub...) and the address.
class _LinkSheet extends StatefulWidget {
  final WorkLink? initial;
  final List<String> types;
  const _LinkSheet({this.initial, required this.types});

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late String _type = widget.initial?.type ?? 'linkedin';
  late final TextEditingController _url = TextEditingController(text: widget.initial?.url);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _done() {
    var url = _url.text.trim();
    if (url.isEmpty) return showCustomSnackBar('jobs_link_needed'.tr);
    if (!url.startsWith(RegExp(r'https?://', caseSensitive: false))) url = 'https://$url';
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.isEmpty || !host.contains('.')) return showCustomSnackBar('jobs_link_wrong'.tr);
    if (_type == 'linkedin' && !host.endsWith('linkedin.com')) return showCustomSnackBar('jobs_link_linkedin_wrong'.tr);
    if (_type == 'github' && !host.endsWith('github.com')) return showCustomSnackBar('jobs_link_github_wrong'.tr);
    Navigator.of(context).pop(WorkLink(type: _type, url: url));
  }

  @override
  Widget build(BuildContext context) => MarketChips(child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text('jobs_card_links'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in widget.types)
                ChoiceChip(avatar: Icon(jobLinkIcon(t)), label: Text(jobLinkLabel(t)), selected: _type == t, showCheckmark: false,
                    onSelected: (_) => setState(() => _type = t)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _url, keyboardType: TextInputType.url, maxLength: 300,
                decoration: jobInput(context, 'jobs_link_hint_$_type'.tr)),
            SizedBox(width: double.infinity, height: 50, child: FilledButton(
              onPressed: _done,
              child: Text('jobs_done'.tr, style: textSemiBold.copyWith(color: Colors.white)),
            )),
          ])),
        );
      }));
}

class _ExperienceSheet extends StatefulWidget {
  final WorkExperience? initial;
  const _ExperienceSheet({this.initial});

  @override
  State<_ExperienceSheet> createState() => _ExperienceSheetState();
}

class _ExperienceSheetState extends State<_ExperienceSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.initial?.title);
  late final TextEditingController _place = TextEditingController(text: widget.initial?.place);
  late final TextEditingController _from = TextEditingController(text: widget.initial?.from);
  late final TextEditingController _to = TextEditingController(text: widget.initial?.to);

  @override
  void dispose() {
    for (final c in [_title, _place, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeLarge, 12, Dimensions.paddingSizeLarge, 16),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text('jobs_card_experience'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 10),
        TextField(controller: _title, maxLength: 60, decoration: jobInput(context, 'jobs_exp_title'.tr)),
        TextField(controller: _place, maxLength: 60, decoration: jobInput(context, 'jobs_exp_place'.tr)),
        Row(children: [
          Expanded(child: TextField(controller: _from, maxLength: 12, decoration: jobInput(context, 'jobs_exp_from'.tr))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _to, maxLength: 12, decoration: jobInput(context, 'jobs_exp_to'.tr))),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, height: 50, child: FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return showCustomSnackBar('jobs_exp_title_needed'.tr);
            String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
            Navigator.of(context).pop(WorkExperience(title: _title.text.trim(), place: v(_place), from: v(_from), to: v(_to)));
          },
          child: Text('jobs_done'.tr, style: textSemiBold.copyWith(color: Colors.white)),
        )),
      ])),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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

/// Become a verified employer (once): who you are, where you are, a document only E-Ride staff see.
class EmployerSetupScreen extends StatefulWidget {
  const EmployerSetupScreen({super.key});

  @override
  State<EmployerSetupScreen> createState() => _EmployerSetupScreenState();
}

class _EmployerSetupScreenState extends State<EmployerSetupScreen> {
  String _kind = 'business';
  final TextEditingController _name = TextEditingController();
  final TextEditingController _about = TextEditingController();
  final TextEditingController _area = TextEditingController();
  Address? _place;
  String? _docType;
  XFile? _doc;
  XFile? _logo;
  JobEmployer? _existing;
  bool _ready = false;

  JobsEmployerController get _c => Get.find<JobsEmployerController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final e = await _c.loadEmployer();
      if (!mounted) return;
      setState(() {
        _existing = e;
        _kind = e?.kind ?? 'business';
        _name.text = e?.name ?? '';
        _about.text = e?.about ?? '';
        _area.text = e?.area ?? '';
        _docType = e?.docType;
        if (e?.lat != null && e?.lng != null) _place = Address(latitude: e!.lat, longitude: e.lng, address: e.address);
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<XFile?> _photo() async {
    final ImageSource? source = await Get.bottomSheet<ImageSource>(Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('market_take_photo'.tr), onTap: () => Get.back(result: ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('market_from_gallery'.tr), onTap: () => Get.back(result: ImageSource.gallery)),
      ])),
    ));
    if (source == null) return null;
    return ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1800);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showCustomSnackBar('jobs_emp_name_needed'.tr);
    if (_area.text.trim().isEmpty) return showCustomSnackBar('jobs_emp_area_needed'.tr);
    final needDoc = _existing == null || !_existing!.hasDoc || _existing!.status == JobEmployer.rejected;
    if (needDoc && (_doc == null || _docType == null)) return showCustomSnackBar('jobs_emp_doc_needed'.tr);
    final ok = await _c.saveEmployer({
      'kind': _kind,
      'name': _name.text.trim(),
      'about': _about.text.trim(),
      'area_label': _area.text.trim(),
      if (_place?.latitude != null) 'lat': '${_place!.latitude}',
      if (_place?.longitude != null) 'lng': '${_place!.longitude}',
      if (_place?.address != null) 'address': _place!.address!,
      if (_docType != null) 'doc_type': _docType!,
    }, logo: _logo, doc: _doc);
    if (!ok || !mounted) return;
    Get.find<JobsController>().loadMeta(force: true);
    if (_existing == null) {
      Get.off(() => const MyJobsScreen(justSetUp: true));
    } else {
      showCustomSnackBar('jobs_emp_saved'.tr, isError: false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final status = _existing?.status;
    return MarketChips(child: Builder(builder: (context) => Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          title: Text(_existing == null ? 'jobs_emp_title'.tr : 'jobs_emp_edit'.tr)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
              if (status == JobEmployer.rejected)
                _Note(bg: jobRedBg, fg: jobRed, text: 'jobs_emp_refused'.trParams({'note': _existing?.reviewNote ?? ''}))
              else if (status == JobEmployer.pending)
                _Note(bg: jobAmberBg, fg: jobAmber, text: 'jobs_emp_pending'.tr)
              else if (status == JobEmployer.verified)
                _Note(bg: jobGreenBg, fg: jobGreen, text: 'jobs_emp_verified_note'.tr)
              else
                _Note(bg: jobBlueBg, fg: jobBlue, text: 'jobs_emp_intro'.tr),
              JobLabel('jobs_emp_who'.tr),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(avatar: const Icon(Icons.storefront_outlined), label: Text('jobs_emp_business'.tr), selected: _kind == 'business',
                    showCheckmark: false, onSelected: (_) => setState(() => _kind = 'business')),
                ChoiceChip(avatar: const Icon(Icons.home_outlined), label: Text('jobs_emp_home'.tr), selected: _kind == 'private',
                    showCheckmark: false, onSelected: (_) => setState(() {
                      _kind = 'private';
                      _docType = 'id';
                    })),
              ]),
              if (_kind == 'private')
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('jobs_emp_home_hint'.tr,
                    style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4))),
              JobLabel(_kind == 'private' ? 'jobs_emp_your_name'.tr : 'jobs_emp_business_name'.tr, hint: 'jobs_emp_name_hint'.tr),
              TextField(controller: _name, maxLength: 120, decoration: jobInput(context, _kind == 'private' ? 'jobs_emp_your_name_ex'.tr : 'jobs_emp_business_ex'.tr)),
              JobLabel('jobs_emp_area'.tr),
              TextField(controller: _area, maxLength: 80, decoration: jobInput(context, 'jobs_emp_area_ex'.tr)),
              JobLabel('jobs_emp_pin'.tr, hint: 'jobs_emp_pin_hint'.tr),
              OutlinedButton.icon(
                onPressed: () async {
                  final a = await pickMarketPoint(title: 'jobs_emp_pin'.tr, hint: 'jobs_emp_pin_hint'.tr);
                  if (a != null && mounted) setState(() => _place = a);
                },
                icon: const Icon(Icons.place_outlined),
                label: Text(_place?.address ?? 'jobs_emp_pin_choose'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              JobLabel('jobs_emp_about'.tr),
              TextField(controller: _about, maxLength: 600, maxLines: 3, decoration: jobInput(context, 'jobs_emp_about_ex'.tr)),
              JobLabel('jobs_emp_logo'.tr),
              Row(children: [
                if (_logo != null) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_logo!.path), width: 56, height: 56, fit: BoxFit.cover)),
                  const SizedBox(width: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await _photo();
                    if (f != null && mounted) setState(() => _logo = f);
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_logo == null ? 'jobs_emp_logo_add'.tr : 'jobs_emp_logo_change'.tr),
                ),
              ]),
              JobLabel('jobs_emp_doc'.tr, hint: 'jobs_emp_doc_hint'.tr),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in (_kind == 'private' ? const ['id'] : const ['licence', 'niu', 'id']))
                  ChoiceChip(label: Text('jobs_doc_$d'.tr), selected: _docType == d, showCheckmark: false, onSelected: (_) => setState(() => _docType = d)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (_doc != null) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(_doc!.path), width: 80, height: 56, fit: BoxFit.cover)),
                  const SizedBox(width: 10),
                ] else if (_existing?.hasDoc ?? false) ...[
                  const Icon(Icons.check_circle_rounded, color: jobGreen),
                  const SizedBox(width: 6),
                  Text('jobs_emp_doc_sent'.tr, style: textMedium.copyWith(color: jobGreen)),
                  const SizedBox(width: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await _photo();
                    if (f != null && mounted) setState(() => _doc = f);
                  },
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(_doc == null && !(_existing?.hasDoc ?? false) ? 'jobs_emp_doc_add'.tr : 'jobs_emp_doc_change'.tr),
                ),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(child: Text('jobs_emp_doc_private'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4))),
              ]),
              const SizedBox(height: 100),
            ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
        child: GetBuilder<JobsEmployerController>(builder: (c) => SizedBox(height: 52, child: FilledButton(
          onPressed: c.saving || !_ready ? null : _save,
          child: c.saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_existing == null ? 'jobs_emp_send'.tr : 'jobs_emp_save'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      )),
    )));
  }
}

class _Note extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String text;
  const _Note({required this.bg, required this.fg, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: fg, height: 1.45)),
      );
}

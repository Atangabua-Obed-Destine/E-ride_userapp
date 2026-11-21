import 'package:ride_sharing_user_app/features/assistant/widgets/help_button.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/id_verification/controllers/id_verification_controller.dart';
import 'package:ride_sharing_user_app/features/id_verification/domain/models/id_verification_model.dart';
import 'package:ride_sharing_user_app/features/id_verification/helpers/id_document_reader.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride ID Verified: send an ID card (front and back) or a passport (photo page) with a selfie, once.
/// The phone reads the number and expiry date from the photo; the person checks them. Pops with true
/// when the ID can be used (verified, or sent and waiting).
class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  IdVerificationController get _c => Get.find<IdVerificationController>();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _number = TextEditingController();
  String _type = 'id_card';
  DateTime? _expires;
  XFile? _front, _back, _selfie;
  bool _reading = false, _readSomething = false, _editing = false;

  @override
  void initState() {
    super.initState();
    final p = Get.find<ProfileController>().profileModel?.data;
    _name.text = '${p?.firstName ?? ''} ${p?.lastName ?? ''}'.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.load());
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _take(String which) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: which == 'selfie' ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null) return;
    setState(() {
      if (which == 'front') _front = file;
      if (which == 'back') _back = file;
      if (which == 'selfie') _selfie = file;
    });
    if (which == 'front' || which == 'back') {
      setState(() => _reading = true);
      final read = await IdDocumentReader.read(file.path);
      if (!mounted) return;
      setState(() {
        _reading = false;
        if (read.number != null && _number.text.trim().isEmpty) {
          _number.text = read.number!;
          _readSomething = true;
        }
        if (read.expires != null && _expires == null) {
          _expires = read.expires;
          _readSomething = true;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _expires ?? now.add(const Duration(days: 365)), firstDate: now, lastDate: DateTime(now.year + 20),
        helpText: 'id_expires_on'.tr);
    if (d != null) setState(() => _expires = d);
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (_front == null || _selfie == null || (_type == 'id_card' && _back == null)) {
      showCustomSnackBar('id_photos_missing'.tr);
      return;
    }
    final e = _expires;
    final s = await _c.submit({
      'doc_type': _type,
      'doc_number': _number.text.trim(),
      'full_name': _name.text.trim(),
      if (e != null) 'expires_on': '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}',
    }, _front!, _type == 'id_card' ? _back : null, _selfie!);
    if (s == null) return;
    setState(() => _editing = false);
    showCustomSnackBar(s.verified ? 'id_verified_now'.tr : s.refused ? (s.refuseReason ?? 'id_refused_title'.tr) : 'id_sent_toast'.tr, isError: s.refused);
    if (s.usable) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('id_title'.tr),
          actions: const [HelpButton(helpKey: 'eride_id'), SizedBox(width: 6)]),
      body: GetBuilder<IdVerificationController>(builder: (c) {
        final IdVerificationStatus? st = c.status;
        if (st == null && c.loading) return const Center(child: CircularProgressIndicator());
        final showForm = _editing || st == null || st.status == 'none' || st.refused;
        return ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
          if (st != null && st.status != 'none') _StatusCard(status: st),
          if (st != null && st.usable && !showForm)
            Padding(padding: const EdgeInsets.only(top: 8), child: TextButton(onPressed: () => setState(() => _editing = true), child: Text('id_use_another'.tr))),
          if (showForm) ...[
            if (st == null || st.status == 'none') _Intro(method: st?.method ?? 'staff'),
            const SizedBox(height: 14),
            Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'id_card', label: Text('id_card'.tr), icon: const Icon(Icons.badge_outlined)),
                  ButtonSegment(value: 'passport', label: Text('id_passport'.tr), icon: const Icon(Icons.menu_book_outlined)),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
                style: SegmentedButton.styleFrom(selectedBackgroundColor: theme.primaryColor, selectedForegroundColor: Colors.white,
                    foregroundColor: textColor),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _PhotoTile(label: _type == 'id_card' ? 'id_front'.tr : 'id_photo_page'.tr, icon: Icons.credit_card, file: _front, onTap: () => _take('front'))),
                if (_type == 'id_card') ...[const SizedBox(width: 10), Expanded(child: _PhotoTile(label: 'id_back'.tr, icon: Icons.flip, file: _back, onTap: () => _take('back')))],
                const SizedBox(width: 10),
                Expanded(child: _PhotoTile(label: 'id_selfie'.tr, icon: Icons.face_retouching_natural, file: _selfie, onTap: () => _take('selfie'))),
              ]),
              const SizedBox(height: 6),
              Text('id_photo_tips'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              if (_reading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
              if (_readSomething && !_reading)
                Padding(padding: const EdgeInsets.only(top: 10), child: Text('id_read_check'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor))),
              const SizedBox(height: 14),
              TextFormField(controller: _name, textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'id_name_on_document'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'id_name_needed'.tr : null),
              const SizedBox(height: 10),
              TextFormField(controller: _number, textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: _type == 'id_card' ? 'id_card_number'.tr : 'id_passport_number'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (v) => (v ?? '').trim().length < 5 ? 'id_number_needed'.tr : null),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: 'id_expires_on'.tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: const Icon(Icons.event)),
                  child: Text(_expires == null ? 'id_expires_pick'.tr : '${_expires!.day.toString().padLeft(2, '0')}/${_expires!.month.toString().padLeft(2, '0')}/${_expires!.year}'),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lock_outline, color: theme.hintColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('id_privacy'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 52, child: ElevatedButton(
                onPressed: c.sending ? null : _send,
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: c.sending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('id_send'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
              )),
            ])),
          ],
        ]);
      }),
    );
  }
}

class _Intro extends StatelessWidget {
  final String method;
  const _Intro({required this.method});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_user_outlined, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('id_intro_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: theme.textTheme.bodyLarge?.color))),
        ]),
        const SizedBox(height: 6),
        Text('id_intro_body'.tr, style: textRegular.copyWith(color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 6),
        Text(method == 'auto' ? 'id_intro_auto'.tr : 'id_intro_staff'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ]),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IdVerificationStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final theme = Theme.of(context);
    final (Color color, IconData icon, String title, String body) = s.verified
        ? (const Color(0xFF15803D), Icons.verified_rounded, 'id_verified_title'.tr, 'id_verified_body'.tr)
        : s.pending
            ? (Colors.orange.shade800, Icons.hourglass_bottom_rounded, 'id_pending_title'.tr, 'id_pending_body'.tr)
            : (Colors.red.shade700, Icons.error_outline, 'id_refused_title'.tr, s.refuseReason ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: color)),
          const SizedBox(height: 2),
          Text(body, style: textRegular.copyWith(color: theme.textTheme.bodyLarge?.color)),
          if (s.maskedNumber != null) ...[
            const SizedBox(height: 6),
            Text('${s.docType == 'passport' ? 'id_passport'.tr : 'id_card'.tr} · ${s.maskedNumber}${s.expiresOn != null ? ' · ${'id_until'.tr} ${s.expiresOn}' : ''}',
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ],
        ])),
      ]),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final XFile? file;
  final VoidCallback onTap;
  const _PhotoTile({required this.label, required this.icon, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 0.85,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: file != null ? const Color(0xFF15803D) : theme.hintColor.withValues(alpha: 0.3), width: file != null ? 2 : 1)),
            child: file != null
                ? Stack(fit: StackFit.expand, children: [
                    Image.file(File(file!.path), fit: BoxFit.cover),
                    Positioned(right: 6, top: 6, child: Container(
                        decoration: const BoxDecoration(color: Color(0xFF15803D), shape: BoxShape.circle), padding: const EdgeInsets.all(3),
                        child: const Icon(Icons.check, color: Colors.white, size: 14))),
                    Positioned(left: 0, right: 0, bottom: 0, child: Container(color: Colors.black54, padding: const EdgeInsets.all(4),
                        child: Text(label, textAlign: TextAlign.center, style: textMedium.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeExtraSmall)))),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: theme.primaryColor, size: 28),
                    const SizedBox(height: 6),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(label, textAlign: TextAlign.center, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
                    Icon(Icons.photo_camera_outlined, size: 16, color: theme.hintColor),
                  ]),
          ),
        ),
      ),
    );
  }
}

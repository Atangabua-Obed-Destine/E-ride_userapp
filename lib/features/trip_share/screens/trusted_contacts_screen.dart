import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/body_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_text_field.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/features/trip_checkin/controllers/trip_checkin_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/controllers/trip_share_controller.dart';
import 'package:ride_sharing_user_app/features/trip_share/domain/models/trusted_contact_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The people a customer shares trips with in one tap. Nothing is sent
/// automatically: the customer taps a name during a trip and WhatsApp opens.
class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the load notifies GetBuilders, which cannot rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<TripShareController>().getContacts(force: true);
      Get.find<TripCheckinController>().loadInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: BodyWidget(
        appBar: AppBarWidget(title: 'trusted_contacts'.tr, showBackButton: true),
        body: GetBuilder<TripCheckinController>(builder: (checkin) => GetBuilder<TripShareController>(builder: (share) {
          final List<TrustedContact>? contacts = share.contacts;
          final bool night = checkin.enabled;
          if (contacts == null) return const Center(child: CircularProgressIndicator());
          final bool full = contacts.length >= TripShareController.maxContacts;
          return ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.shield_outlined, color: theme.primaryColor),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(child: Text('trusted_contacts_intro'.tr,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4))),
            ]),
            if (night && contacts.isNotEmpty) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.nightlight_round, color: theme.primaryColor),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Text(
                  'night_share_intro'.trParams({
                    'from': '${checkin.info!.nightFrom.toString().padLeft(2, '0')}:00',
                    'to': '${checkin.info!.nightTo.toString().padLeft(2, '0')}:00',
                  }),
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4),
                )),
              ]),
            ],
            const SizedBox(height: Dimensions.paddingSizeLarge),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(Icons.people_alt_outlined, size: 56, color: theme.hintColor.withValues(alpha: 0.5)),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text('trusted_contacts_empty'.tr, textAlign: TextAlign.center, style: textMedium.copyWith(color: theme.hintColor)),
                ]),
              ),
            for (final TrustedContact contact in contacts)
              Container(
                margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSize, vertical: Dimensions.paddingSizeSmall),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.hintColor.withValues(alpha: 0.18)),
                ),
                child: Column(children: [Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                    child: Text(contact.name.isEmpty ? '?' : contact.name.characters.first.toUpperCase(),
                        style: textBold.copyWith(color: theme.primaryColor)),
                  ),
                  const SizedBox(width: Dimensions.paddingSize),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textSemiBold),
                    Text(contact.phone, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                  ])),
                  IconButton(
                    tooltip: 'edit'.tr,
                    icon: Icon(Icons.edit_outlined, color: theme.hintColor),
                    onPressed: () => _edit(context, contact),
                  ),
                  IconButton(
                    tooltip: 'delete'.tr,
                    icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    onPressed: () => _delete(context, share, contact),
                  ),
                ]),
                if (night) ...[
                  Divider(height: Dimensions.paddingSizeDefault, color: theme.hintColor.withValues(alpha: 0.15)),
                  Row(children: [
                    Icon(Icons.nightlight_outlined, size: 18, color: contact.nightShare ? theme.primaryColor : theme.hintColor),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Expanded(child: Text('night_share_label'.tr,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: contact.nightShare ? null : theme.hintColor))),
                    if (checkin.nightBusy.contains(contact.id))
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Switch(
                        value: contact.nightShare,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (on) => checkin.setNightShare(contact, on),
                      ),
                  ]),
                ],
              ])),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            if (full)
              Text('trusted_contacts_full'.tr, textAlign: TextAlign.center,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))
            else
              ButtonWidget(buttonText: 'add_contact'.tr, onPressed: () => _edit(context, null)),
          ]);
        })),
      ),
    );
  }

  Future<void> _delete(BuildContext context, TripShareController share, TrustedContact contact) async {
    final ThemeData theme = Theme.of(context);
    final bool? yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('remove_contact_title'.trParams({'name': contact.name})),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('delete'.tr),
        ),
      ],
    ));
    if (yes == true) share.deleteContact(contact);
  }

  void _edit(BuildContext context, TrustedContact? contact) {
    Get.bottomSheet(_ContactForm(contact: contact), isScrollControlled: true, backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Dimensions.paddingSizeLarge))));
  }
}

class _ContactForm extends StatefulWidget {
  final TrustedContact? contact;
  const _ContactForm({this.contact});

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final FocusNode _nameNode = FocusNode();
  final FocusNode _phoneNode = FocusNode();
  late String _dialCode;

  @override
  void initState() {
    super.initState();
    _dialCode = Get.find<ConfigController>().countryDialCode;
    final TrustedContact? contact = widget.contact;
    if (contact != null) {
      _name.text = contact.name;
      String phone = contact.phone;
      if (phone.startsWith(_dialCode)) phone = phone.substring(_dialCode.length);
      _phone.text = phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nameNode.dispose();
    _phoneNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get.bottomSheet already lifts the sheet above the keyboard.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: GetBuilder<TripShareController>(builder: (share) {
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.contact == null ? 'add_contact'.tr : 'edit_contact'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          CustomTextField(
            hintText: 'contact_name_hint'.tr,
            controller: _name,
            focusNode: _nameNode,
            nextFocus: _phoneNode,
            capitalization: TextCapitalization.words,
            inputAction: TextInputAction.next,
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          CustomTextField(
            isCodePicker: true,
            hintText: 'phone'.tr,
            inputType: TextInputType.phone,
            countryDialCode: _dialCode,
            controller: _phone,
            focusNode: _phoneNode,
            inputAction: TextInputAction.done,
            onCountryChanged: (CountryCode code) => setState(() => _dialCode = code.dialCode ?? _dialCode),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          share.savingContact
              ? const Center(child: CircularProgressIndicator())
              : ButtonWidget(buttonText: 'save'.tr, onPressed: () => _save(share)),
        ]);
      }),
    );
  }

  Future<void> _save(TripShareController share) async {
    final String name = _name.text.trim();
    final String local = _phone.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (name.isEmpty) {
      showCustomSnackBar('contact_name_required'.tr);
      return;
    }
    if (local.length < 6) {
      showCustomSnackBar('enter_valid_phone_number'.tr);
      return;
    }
    final bool ok = await share.saveContact(id: widget.contact?.id, name: name, phone: '$_dialCode$local');
    if (ok) Get.back();
  }
}

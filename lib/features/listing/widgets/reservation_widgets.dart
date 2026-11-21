import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/listing/controllers/listing_controller.dart';
import 'package:ride_sharing_user_app/features/listing/domain/models/listing_model.dart';
import 'package:ride_sharing_user_app/features/listing/widgets/listing_widgets.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

// Homes & spaces reservation money: E-Ride holds what the seeker pays until the
// move-in. The server decides every state; these widgets show it and offer the
// actions that state allows.

String _money(double v) => PriceConverter.convertPrice(v);

String _time(DateTime? d) {
  if (d == null) return '';
  return '${ListingText.day(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Reserve after an accepted visit: pick the move-in date, then pay (wallet or mobile money).
class ReserveSheet extends StatefulWidget {
  final String visitId;
  const ReserveSheet({super.key, required this.visitId});

  @override
  State<ReserveSheet> createState() => _ReserveSheetState();
}

class _ReserveSheetState extends State<ReserveSheet> {
  late DateTime moveIn = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<ListingController>().preparePayment());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<ListingController>(builder: (c) {
      final ListingVisit? visit = c.visitById(widget.visitId);
      final ListingReservation? r = visit?.reservation;
      final double amount = r?.isAwaiting ?? false ? r!.amount : (visit?.listing?.reservationAmount ?? 0);
      final bool paying = r?.isAwaiting ?? false;
      return ListingSheet(
        title: 'listing_reserve_title'.tr,
        subtitle: visit?.listing?.title,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Dimensions.paddingSize),
            decoration: BoxDecoration(color: listingVerifiedGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_money(amount), style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 4),
              Text('listing_reserve_counts_toward_rent'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
            ]),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          for (final rule in const ['listing_reserve_rule_held', 'listing_reserve_rule_owner', 'listing_reserve_rule_problem'])
            Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: listingVerifiedGreen),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(child: Text(rule.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall))),
              ]),
            ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          if (!paying) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text('listing_move_in_date'.tr),
              subtitle: Text(ListingText.day(moveIn)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final DateTime now = DateTime.now();
                final DateTime? d = await showDatePicker(context: context, initialDate: moveIn,
                    firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 30)));
                if (d != null) setState(() => moveIn = d);
              },
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            ButtonWidget(buttonText: 'listing_reserve_continue'.tr, onPressed: c.saving || visit == null ? null : () => c.reserve(widget.visitId, moveIn)),
          ] else ...[
            Text('listing_reserve_pay_by'.trParams({'time': _time(r!.payDueAt)}), style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall)),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            // The wallet only when the admin offers it (Ways to pay).
            if ((c.walletBalance ?? 0) >= amount && (Get.find<ConfigController>().config?.paymentWalletStatus ?? true))
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: ButtonWidget(
                  buttonText: 'listing_pay_from_wallet'.trParams({'balance': _money(c.walletBalance ?? 0)}),
                  onPressed: c.payingWith != null ? null : () async {
                    if (await c.payReservationWithWallet(r.id) && context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            for (final g in c.gateways)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                child: ButtonWidget(
                  transparent: true, showBorder: true,
                  buttonText: c.payingWith == g.gateway ? 'listing_waiting_payment'.tr : 'deposit_pay_with'.trParams({'method': g.gatewayTitle ?? g.gateway ?? ''}),
                  onPressed: c.payingWith != null ? null : () async {
                    if (await c.payReservationWithGateway(widget.visitId, r.id, g.gateway ?? '') && context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            Text('listing_reserve_momo_fee'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ],
        ],
      );
    });
  }
}

/// A visit's reservation, as the seeker or the owner sees it, with what they can do now.
class ReservationPanel extends StatelessWidget {
  final ListingVisit visit;
  const ReservationPanel({super.key, required this.visit});

  @override
  Widget build(BuildContext context) {
    final ListingReservation r = visit.reservation!;
    final ListingController c = Get.find<ListingController>();
    final ThemeData theme = Theme.of(context);
    final bool owner = visit.asOwner;
    final String moveIn = ListingText.day(r.moveInDate);

    String title;
    String? body;
    Color tone = theme.primaryColor;
    final List<Widget> actions = [];

    Widget btn(String label, VoidCallback? onTap, {bool main = false}) => main
        ? FilledButton(onPressed: c.saving ? null : onTap, child: Text(label))
        : OutlinedButton(onPressed: c.saving ? null : onTap, child: Text(label));

    switch (r.status) {
      case 'awaiting':
        title = 'listing_res_awaiting'.tr;
        body = 'listing_reserve_pay_by'.trParams({'time': _time(r.payDueAt)});
        if (!owner) {
          actions.add(btn('listing_res_pay_now'.tr, () => ListingSheet.show(ReserveSheet(visitId: visit.id)), main: true));
          actions.add(btn('listing_res_cancel'.tr, () => c.cancelReservation(r.id)));
        }
        break;
      case 'held':
        tone = listingAmber;
        if (owner) {
          title = 'listing_res_owner_held'.trParams({'name': visit.otherName, 'amount': _money(r.amount)});
          body = 'listing_res_owner_accept_by'.trParams({'time': _time(r.acceptDueAt), 'date': moveIn});
          actions.add(btn('listing_res_accept'.tr, () => _accept(context, c, r), main: true));
          actions.add(btn('listing_res_decline'.tr, () async {
            if (await listingConfirm('listing_res_decline_q'.tr, 'listing_res_decline_body'.tr, 'listing_res_decline'.tr)) {
              c.respondReservation(r.id, 'decline');
            }
          }));
        } else {
          title = 'listing_res_held'.trParams({'amount': _money(r.amount)});
          body = 'listing_res_waiting_owner'.trParams({'time': _time(r.acceptDueAt)});
          actions.add(btn('listing_res_cancel'.tr, () async {
            if (await listingConfirm('listing_res_cancel_q'.tr, 'listing_res_cancel_body'.tr, 'listing_res_cancel'.tr)) {
              c.cancelReservation(r.id);
            }
          }));
        }
        break;
      case 'reserved':
        tone = listingVerifiedGreen;
        if (owner) {
          title = 'listing_res_owner_reserved'.trParams({'date': moveIn});
          body = 'listing_res_owner_paid_after'.trParams({'amount': _money(r.amount)});
          if (r.moveInReached) actions.add(btn('listing_res_no_show'.tr, () => ListingSheet.show(ReservationProblemSheet(reservation: r, asOwner: true))));
        } else {
          title = 'listing_res_reserved'.trParams({'date': moveIn});
          body = 'listing_res_reserved_body'.trParams({'amount': _money(r.amount), 'date': ListingText.day(r.releaseDueAt)});
          actions.add(btn('listing_res_moved_in'.tr, () async {
            if (await listingConfirm('listing_res_moved_in_q'.tr, 'listing_res_moved_in_body'.tr, 'listing_res_moved_in'.tr)) {
              c.movedIn(r.id);
            }
          }, main: true));
          actions.add(btn('listing_res_report'.tr, () => ListingSheet.show(ReservationProblemSheet(reservation: r, asOwner: false))));
        }
        break;
      case 'problem':
        tone = theme.colorScheme.error;
        title = 'listing_res_problem'.tr;
        body = 'listing_res_problem_body'.tr;
        break;
      case 'released':
        tone = listingVerifiedGreen;
        if (owner) {
          final ListingPayoutInfo? p = r.payout;
          title = 'listing_res_owner_released'.trParams({'amount': _money(r.ownerAmount ?? 0)});
          body = p == null ? null : p.isPaid
              ? 'listing_res_payout_paid'.trParams({'phone': p.phone, 'date': ListingText.day(p.paidAt), 'ref': p.reference ?? ''})
              : 'listing_res_payout_pending'.trParams({'phone': p.phone});
        } else {
          title = 'listing_res_released'.tr;
          body = r.refundedAmount > 0 ? 'listing_res_part_refunded'.trParams({'amount': _money(r.refundedAmount)}) : null;
        }
        break;
      case 'refunded':
        tone = theme.hintColor;
        if (owner) {
          title = 'listing_res_owner_refunded'.tr;
        } else {
          final ListingPayoutInfo? p = r.payout;
          title = 'listing_res_refunded'.trParams({'amount': _money(r.refundedAmount)});
          if (p != null) {
            body = p.isPaid
                ? 'listing_res_refund_momo_paid'.trParams({'phone': p.phone, 'ref': p.reference ?? ''})
                : 'listing_res_refund_momo_pending'.trParams({'phone': p.phone});
          } else if (r.canRefundToMomo) {
            actions.add(btn('listing_res_refund_momo'.tr, () => _refundToMomo(c, r)));
          }
        }
        break;
      default:
        return const SizedBox();
    }
    final String? note = r.decisionNote;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
      padding: const EdgeInsets.all(Dimensions.paddingSize),
      decoration: BoxDecoration(color: tone.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_rounded, size: 18, color: tone),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text(title, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
        ]),
        if (body != null && body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyMedium?.color)),
        ],
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${'listing_eride_says'.tr}: $note', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Wrap(spacing: Dimensions.paddingSizeSmall, runSpacing: Dimensions.paddingSizeSmall, children: actions),
        ],
      ]),
    );
  }

  /// The owner accepts, confirming or changing the move-in date.
  Future<void> _accept(BuildContext context, ListingController c, ListingReservation r) async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year, now.month, now.day);
    DateTime initial = r.moveInDate ?? first;
    if (initial.isBefore(first)) initial = first;
    final DateTime? d = await showDatePicker(context: context, initialDate: initial, firstDate: first,
        lastDate: now.add(const Duration(days: 30)), helpText: 'listing_res_confirm_move_in'.tr);
    if (d == null) return;
    if (await listingConfirm('listing_res_accept_q'.tr, 'listing_res_accept_body'.trParams({'date': ListingText.day(d)}), 'listing_res_accept'.tr)) {
      c.respondReservation(r.id, 'accept', moveIn: d);
    }
  }

  Future<void> _refundToMomo(ListingController c, ListingReservation r) async {
    final TextEditingController phone = TextEditingController(text: Get.find<ProfileController>().profileModel?.data?.phone ?? '');
    final bool? ok = await Get.dialog<bool>(AlertDialog(
      title: Text('listing_res_refund_momo'.tr),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('listing_res_refund_momo_body'.trParams({'amount': _money(r.refundedAmount)})),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'listing_momo_number'.tr)),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('listing_cancel'.tr)),
        TextButton(onPressed: () => Get.back(result: true), child: Text('listing_send'.tr)),
      ],
    ));
    if (ok == true && phone.text.trim().length >= 9) await c.refundToMomo(r.id, phone.text.trim());
    phone.dispose();
  }
}

/// "Report a problem" (seeker) or "Seeker didn't come" (owner): E-Ride keeps the money and decides.
class ReservationProblemSheet extends StatefulWidget {
  final ListingReservation reservation;
  final bool asOwner;
  const ReservationProblemSheet({super.key, required this.reservation, required this.asOwner});

  @override
  State<ReservationProblemSheet> createState() => _ReservationProblemSheetState();
}

class _ReservationProblemSheetState extends State<ReservationProblemSheet> {
  late String? reason = widget.asOwner ? 'no_show' : null;
  final TextEditingController note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> reasons = widget.asOwner ? const ['no_show', 'other'] : const ['given_away', 'not_as_described', 'cancel', 'other'];
    return GetBuilder<ListingController>(builder: (c) => ListingSheet(
      title: widget.asOwner ? 'listing_res_no_show'.tr : 'listing_res_report'.tr,
      subtitle: 'listing_res_problem_hint'.tr,
      children: [
        for (final r in reasons)
          ListingOption(selected: reason == r, label: 'listing_res_reason_$r'.tr, onTap: () => setState(() => reason = r)),
        TextField(controller: note, maxLines: 3, maxLength: 1000,
            decoration: InputDecoration(hintText: 'listing_res_problem_note'.tr, border: const OutlineInputBorder())),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        ButtonWidget(buttonText: 'listing_send'.tr, onPressed: reason == null || c.saving ? null : () async {
          final bool ok = reason == 'cancel'
              ? await c.cancelReservation(widget.reservation.id, note: note.text.trim())
              : await c.reservationProblem(widget.reservation.id, reason!, note.text.trim());
          if (ok && context.mounted) Navigator.of(context).pop();
        }),
      ],
    ));
  }
}

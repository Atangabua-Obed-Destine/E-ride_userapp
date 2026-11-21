import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chats_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_item_screen.dart';
import 'package:ride_sharing_user_app/features/market/helpers/market_delivery.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_booking_screen.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_order_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_point_sheet.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/features/trip/screens/trip_details_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// One chat about one item. Text and photos; the buyer can share a delivery
/// point, and the seller books an E-Ride parcel to it from that card.
/// Payment is arranged between them: E-Ride never holds the money.
class MarketChatScreen extends StatefulWidget {
  final String chatId;
  const MarketChatScreen({super.key, required this.chatId});

  @override
  State<MarketChatScreen> createState() => _MarketChatScreenState();
}

class _MarketChatScreenState extends State<MarketChatScreen> with WidgetsBindingObserver {
  final TextEditingController _text = TextEditingController();
  late final MarketChatController _chats = Get.find<MarketChatController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _chats.open(widget.chatId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _chats.refreshChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chats.close();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (await _chats.sendText(text)) _text.clear();
  }

  Future<void> _photo() async {
    final ImageSource? source = await Get.bottomSheet<ImageSource>(Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('market_take_photo'.tr), onTap: () => Get.back(result: ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('market_from_gallery'.tr), onTap: () => Get.back(result: ImageSource.gallery)),
      ])),
    ));
    if (source == null) return;
    final photo = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1400);
    if (photo != null) await _chats.sendPhoto(photo);
  }

  Future<void> _askDelivery() async {
    final Address? point = await pickMarketPoint(hint: 'market_ask_delivery_hint'.tr);
    if (point == null || point.latitude == null || point.longitude == null) return;
    await _chats.askDelivery(point.latitude!, point.longitude!, point.address ?? '');
  }

  /// The seller books the E-Ride parcel to the buyer's point; the seller pays the deposit.
  Future<void> _sendWithEride(MarketChat chat, MarketMessage point) => startMarketDelivery(
        chatId: chat.id,
        lat: point.latitude!,
        lng: point.longitude!,
        address: point.address,
        receiverName: chat.receiver?.name.isNotEmpty == true ? chat.receiver!.name : chat.otherName,
        receiverPhone: chat.receiver?.phone,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return GetBuilder<MarketChatController>(builder: (chats) {
      final MarketChat? chat = chats.chat?.id == widget.chatId ? chats.chat : null;
      final messages = chat == null ? const <MarketMessage>[] : chats.messages;
      final bool blockedForMe = chat != null && !chat.isSeller && chat.buyerBlocked;
      final bool closed = chat != null && !chat.shopLive;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          title: chat == null ? null : Row(children: [
            MarketShopAvatar(name: chat.otherName, logo: chat.isSeller ? null : chat.shop?.logo, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(chat.otherName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
                if (!chat.isSeller && chat.shop?.verified == true) ...[const SizedBox(width: 4), const MarketVerifiedBadge(size: 14)],
              ]),
              Text((chat.item?.isService == true
                      ? (chat.isSeller ? 'market_role_client' : 'market_role_provider')
                      : (chat.isSeller ? 'market_role_buyer' : 'market_role_seller')).tr,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            ])),
          ]),
          actions: [
            if (chat != null)
              PopupMenuButton<String>(
                color: Theme.of(context).cardColor,
                onSelected: (v) {
                  if (v == 'item' && chat.item != null) Get.to(() => MarketItemScreen(code: chat.item!.code, initial: chat.item));
                  if (v == 'report' && chat.item != null && chat.shop != null) {
                    showMarketReportSheet(code: chat.item!.code, shopSlug: chat.shop!.slug);
                  }
                  if (v == 'block') chats.blockBuyer(!chat.buyerBlocked);
                },
                itemBuilder: (_) => [
                  if (chat.item != null) PopupMenuItem(value: 'item', child: Text('market_view_item'.tr)),
                  if (!chat.isSeller) PopupMenuItem(value: 'report', child: Text('market_report_item'.tr)),
                  if (chat.isSeller) PopupMenuItem(value: 'block', child: Text((chat.buyerBlocked ? 'market_unblock_buyer' : 'market_block_buyer').tr)),
                ],
              ),
          ],
        ),
        body: chat == null
            ? Center(child: chats.loading ? const CircularProgressIndicator() : Text('market_chat_gone'.tr))
            : Column(children: [
                if (chat.item != null) _ItemBar(item: chat.item!),
                Expanded(child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  itemCount: messages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == messages.length) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                        child: MarketScamNotice(text: (chat.item?.isService == true
                            ? (chat.isSeller ? 'market_chat_notice_provider' : 'market_chat_notice_client')
                            : (chat.isSeller ? 'market_chat_notice_seller' : 'market_chat_notice_buyer')).tr),
                      );
                    }
                    final m = messages[messages.length - 1 - i];
                    return _Bubble(
                      message: m,
                      onSendWithEride: chat.isSeller && m.type == 'delivery_point' && m.latitude != null ? () => _sendWithEride(chat, m) : null,
                      onOpenDelivery: chat.isSeller && m.delivery != null ? () => Get.to(() => TripDetailsScreen(tripId: m.delivery!.tripId)) : null,
                    );
                  },
                )),
                if (blockedForMe || closed || (chat.isSeller && chat.buyerBlocked))
                  SafeArea(top: false, child: Container(
                    width: double.infinity,
                    color: theme.cardColor,
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: Text(closed ? 'market_chat_shop_closed'.tr : (blockedForMe ? 'market_chat_blocked_buyer'.tr : 'market_chat_you_blocked'.tr),
                        textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
                  ))
                else
                  _Composer(
                    controller: _text,
                    sending: chats.sending,
                    onSend: _send,
                    onPhoto: _photo,
                    onAskDelivery: !chat.isSeller && chat.item?.isDigital != true && chat.item?.isService != true ? _askDelivery : null,
                  ),
              ]),
      );
    });
  }
}

class _ItemBar extends StatelessWidget {
  final MarketItem item;
  const _ItemBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      child: InkWell(
        onTap: () => Get.to(() => MarketItemScreen(code: item.code, initial: item)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: 8),
          child: Row(children: [
            if (item.cover != null) ImageWidget(image: item.cover!, width: 40, height: 40, radius: 8, fit: BoxFit.cover),
            const SizedBox(width: 10),
            Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
            Text(marketPrice(item.price), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
          ]),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final MarketMessage message;
  final VoidCallback? onSendWithEride;
  final VoidCallback? onOpenDelivery;
  const _Bubble({required this.message, this.onSendWithEride, this.onOpenDelivery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.mine;
    final Color bg = mine ? theme.primaryColor : theme.cardColor;
    final Color fg = mine ? Colors.white : (theme.textTheme.bodyLarge?.color ?? Colors.black);
    Widget content;
    switch (message.type) {
      case 'photo':
        content = GestureDetector(
          onTap: () => Get.to(() => MarketPhotoViewer(photos: [message.photo!])),
          child: ImageWidget(image: message.photo ?? '', width: 200, height: 200, radius: 12, fit: BoxFit.cover),
        );
        break;
      case 'delivery_point':
        content = _Card(color: theme.cardColor, children: [
          Row(children: [
            Icon(Icons.location_on_rounded, color: theme.primaryColor, size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text((mine ? 'market_delivery_point_mine' : 'market_delivery_point_theirs').tr,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
          ]),
          if (message.address != null) ...[
            const SizedBox(height: 4),
            Text(message.address!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ],
          if (onSendWithEride != null) ...[
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: onSendWithEride,
              icon: const Icon(Icons.delivery_dining_rounded, size: 18),
              label: Text('market_send_with_eride'.tr),
            )),
            const SizedBox(height: 4),
            Text('market_send_with_eride_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ] else if (mine) ...[
            const SizedBox(height: 4),
            Text('market_delivery_point_wait'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
          ],
        ]);
        break;
      case 'order':
      case 'booking':
        final bool isBooking = message.type == 'booking';
        final String? target = isBooking ? message.bookingId : message.orderId;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(child: Material(
            color: theme.hintColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: target == null ? null : () => Get.to(() => isBooking ? MarketBookingScreen(bookingId: target) : MarketOrderScreen(orderId: target)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isBooking ? Icons.event_available_outlined : Icons.receipt_long_outlined, size: 15, color: theme.primaryColor),
                  const SizedBox(width: 6),
                  Flexible(child: Text(message.body ?? '', textAlign: TextAlign.center,
                      style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
                  if (target != null) ...[const SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 16, color: theme.hintColor)],
                ]),
              ),
            ),
          )),
        );
      case 'delivery_booked':
        final d = message.delivery;
        content = _Card(color: theme.cardColor, onTap: onOpenDelivery, children: [
          Row(children: [
            Icon(Icons.local_shipping_rounded, color: theme.primaryColor, size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text('market_delivery_booked'.tr,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color))),
          ]),
          if (d != null) ...[
            const SizedBox(height: 4),
            Text('${d.refId != null ? '#${d.refId} · ' : ''}${'market_delivery_status_${d.status ?? 'pending'}'.tr}',
                style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ],
          const SizedBox(height: 4),
          Text((mine ? 'market_delivery_booked_seller' : 'market_delivery_booked_buyer').tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
        ]);
        break;
      default:
        content = Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4), bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Text(message.body ?? '', style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: fg, height: 1.35)),
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        content,
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
          child: Text(marketChatTime(message.createdAt), style: textRegular.copyWith(fontSize: 9, color: theme.hintColor)),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color color;
  final VoidCallback? onTap;
  const _Card({required this.children, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback? onAskDelivery;
  const _Composer({required this.controller, required this.sending, required this.onSend, required this.onPhoto, this.onAskDelivery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(top: false, child: Container(
      color: theme.cardColor,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (onAskDelivery != null)
          Align(alignment: Alignment.centerLeft, child: Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: ActionChip(
              avatar: Icon(Icons.location_on_outlined, size: 16, color: theme.primaryColor),
              label: Text('market_ask_delivery'.tr),
              onPressed: onAskDelivery,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.4)),
            ),
          )),
        Row(children: [
          IconButton(tooltip: 'market_send_photo'.tr, onPressed: sending ? null : onPhoto, icon: const Icon(Icons.add_photo_alternate_outlined)),
          Expanded(child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'market_type_message'.tr,
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: theme.hintColor.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          )),
          const SizedBox(width: 4),
          sending
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton.filled(tooltip: 'market_send'.tr, onPressed: onSend, icon: const Icon(Icons.send_rounded, size: 20)),
        ]),
      ]),
    ));
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/market/controllers/market_chat_controller.dart';
import 'package:ride_sharing_user_app/features/market/domain/models/market_models.dart';
import 'package:ride_sharing_user_app/features/market/screens/market_chat_screen.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Every market chat, as a buyer and as a seller, newest first.
class MarketChatsScreen extends StatefulWidget {
  const MarketChatsScreen({super.key});

  @override
  State<MarketChatsScreen> createState() => _MarketChatsScreenState();
}

class _MarketChatsScreenState extends State<MarketChatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<MarketChatController>().loadInbox());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.cardColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor, foregroundColor: theme.textTheme.bodyLarge?.color, surfaceTintColor: Colors.transparent,
        title: Text('market_chats'.tr),
      ),
      body: GetBuilder<MarketChatController>(builder: (chats) {
        if (chats.inboxLoading && chats.chats.isEmpty) return const Center(child: CircularProgressIndicator());
        if (chats.chats.isEmpty) {
          return MarketEmpty(icon: Icons.chat_bubble_outline_rounded, title: 'market_no_chats'.tr, body: 'market_no_chats_body'.tr);
        }
        return RefreshIndicator(
          onRefresh: chats.loadInbox,
          child: ListView.separated(
            itemCount: chats.chats.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 76, color: theme.hintColor.withValues(alpha: 0.12)),
            itemBuilder: (_, i) => _ChatRow(chat: chats.chats[i]),
          ),
        );
      }),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final MarketChat chat;
  const _ChatRow({required this.chat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final bool unread = chat.unread > 0;
    return InkWell(
      onTap: () async {
        await Get.to(() => MarketChatScreen(chatId: chat.id));
        Get.find<MarketChatController>().loadInbox();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: 12),
        child: Row(children: [
          chat.item?.cover != null
              ? ImageWidget(image: chat.item!.cover!, width: 50, height: 50, radius: 12, fit: BoxFit.cover)
              : MarketShopAvatar(name: chat.otherName, logo: chat.shop?.logo, size: 50),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(chat.otherName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: (unread ? textBold : textSemiBold).copyWith(fontSize: Dimensions.fontSizeDefault, color: textColor))),
              Text(marketChatTime(chat.lastMessageAt), style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            ]),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                margin: const EdgeInsets.only(right: 6, top: 2),
                decoration: BoxDecoration(
                  color: (chat.isSeller ? theme.primaryColor : marketVerified).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text((chat.isSeller ? 'market_role_selling' : 'market_role_buying').tr,
                    style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: chat.isSeller ? theme.primaryColor : marketVerified)),
              ),
              Expanded(child: Text(chat.item?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(chat.lastMessage ?? 'market_say_hello'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: (unread ? textMedium : textRegular).copyWith(fontSize: Dimensions.fontSizeSmall, color: unread ? textColor : theme.hintColor))),
              if (unread)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(10)),
                  child: Text('${chat.unread}', style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Colors.white)),
                ),
            ]),
          ])),
        ]),
      ),
    );
  }
}

/// "14:05" today, "12/11" before.
String marketChatTime(String? iso) {
  final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  if (t.year == now.year && t.month == now.month && t.day == now.day) return '${two(t.hour)}:${two(t.minute)}';
  return '${two(t.day)}/${two(t.month)}';
}

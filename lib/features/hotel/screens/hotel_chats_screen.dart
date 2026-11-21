import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/bus/widgets/bus_widgets.dart';
import 'package:ride_sharing_user_app/features/hotel/controllers/hotel_controller.dart';
import 'package:ride_sharing_user_app/features/hotel/domain/models/hotel_models.dart';
import 'package:ride_sharing_user_app/features/hotel/screens/hotel_chat_screen.dart';
import 'package:ride_sharing_user_app/features/hotel/widgets/hotel_widgets.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// My questions to hotels: going ones first, each opening its chat.
class HotelChatsScreen extends StatefulWidget {
  const HotelChatsScreen({super.key});

  @override
  State<HotelChatsScreen> createState() => _HotelChatsScreenState();
}

class _HotelChatsScreenState extends State<HotelChatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.find<HotelController>().loadInquiries());
  }

  String _status(HotelInquiry q) {
    switch (q.status) {
      case 'open':
        return 'hotel_status_waiting'.tr;
      case 'answered':
        return 'hotel_status_answered'.tr;
      case 'kept':
        return q.keptUntil == null ? 'hotel_status_kept'.tr : 'hotel_kept_until'.trParams({'time': busWhen(q.keptUntil!)});
      case 'arrived':
        return 'hotel_status_arrived'.tr;
      default:
        return 'hotel_status_closed'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('hotel_my_chats'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
        backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent,
      ),
      body: GetBuilder<HotelController>(builder: (c) {
        final list = c.inquiries;
        if (list == null) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: () => c.loadInquiries(),
          child: list.isEmpty
              ? ListView(padding: const EdgeInsets.all(32), children: [
                  const SizedBox(height: 60),
                  Icon(Icons.chat_bubble_outline_rounded, size: 52, color: theme.hintColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('hotel_no_chats'.tr, textAlign: TextAlign.center, style: textRegular.copyWith(color: theme.hintColor)),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final q = list[i];
                    final kept = q.status == 'kept';
                    return Material(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Get.to(() => HotelChatScreen(inquiryId: q.id)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            HotelPhoto(url: q.hotel.photo, width: 56, height: 56, radius: BorderRadius.circular(10)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(q.hotel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textBold.copyWith(color: textColor))),
                                if (q.unread > 0 && q.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(10)),
                                    child: Text('${q.unread}', style: textBold.copyWith(fontSize: 11, color: Colors.white)),
                                  ),
                              ]),
                              Text(hotelDates(q.checkIn, q.checkOut), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                              const SizedBox(height: 4),
                              Text(_status(q), style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall,
                                  color: kept ? hotelAmber : q.isActive ? textColor : theme.hintColor)),
                            ])),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        );
      }),
    );
  }
}

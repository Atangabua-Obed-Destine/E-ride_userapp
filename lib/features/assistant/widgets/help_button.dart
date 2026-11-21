import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/screens/assistant_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// A small ⓘ next to something new users won't know. Opens that topic's info
/// sheet from the knowledge pack; nothing shows until the sheet is loaded.
class HelpButton extends StatelessWidget {
  final String helpKey;
  final Color? color;
  final double size;
  const HelpButton({super.key, required this.helpKey, this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AssistantController>()) return const SizedBox.shrink();
    return GetBuilder<AssistantController>(builder: (c) {
      final sheet = c.sheet(helpKey);
      if (sheet == null) return const SizedBox.shrink();
      return IconButton(
        tooltip: sheet.title,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        onPressed: () => showHelpSheet(sheet),
        icon: Icon(Icons.info_outline_rounded, size: size, color: color ?? Theme.of(context).primaryColor),
      );
    });
  }
}

/// "How paying works here": numbered steps, then Ask more / Got it.
Future<void> showHelpSheet(HelpSheet sheet) {
  final c = Get.find<AssistantController>();
  return Get.bottomSheet(
    Builder(builder: (context) {
      final theme = Theme.of(context);
      final textColor = theme.textTheme.bodyLarge?.color;
      return Container(
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)))),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.lightbulb_outline_rounded, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(sheet.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: textColor))),
            ]),
            const SizedBox(height: 16),
            for (int i = 0; i < sheet.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 26, height: 26, alignment: Alignment.center,
                    decoration: BoxDecoration(color: textColor ?? Colors.black, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: textBold.copyWith(fontSize: 13, color: theme.cardColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(sheet.steps[i], style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: textColor))),
                ]),
              ),
            const SizedBox(height: 6),
            Row(children: [
              if (c.enabled) ...[
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () {
                    Get.back();
                    // Open empty: the sheet already explained the basics, so the customer asks the rest.
                    Get.to(() => const AssistantScreen());
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text('assistant_ask_more'.tr, style: textBold),
                )),
                const SizedBox(width: 10),
              ],
              Expanded(child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () => Get.back(),
                child: Text('assistant_got_it'.tr, style: textBold.copyWith(color: Colors.white)),
              )),
            ]),
          ]),
        ),
      );
    }),
    isScrollControlled: true,
  );
}

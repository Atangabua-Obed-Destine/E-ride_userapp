import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/assistant_actions.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// "Did you know?" on Home: one service the customer has not tried yet, in a
/// line, with the button that opens it. Always on Home: the close button (or
/// the card's button) hides it until the app is opened again.
class DidYouKnowCard extends StatelessWidget {
  const DidYouKnowCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AssistantController>()) return const SizedBox.shrink();
    return GetBuilder<AssistantController>(builder: (c) {
      final AssistantTip? tip = c.tip;
      return AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: tip == null
              ? const SizedBox(width: double.infinity, key: ValueKey('no-tip'))
              : Padding(
                  key: ValueKey(tip.key),
                  padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
                  child: _Card(tip: tip, controller: c),
                ),
        ),
      );
    });
  }
}

class _Card extends StatefulWidget {
  final AssistantTip tip;
  final AssistantController controller;
  const _Card({required this.tip, required this.controller});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.controller.tipSeen(widget.tip));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final AssistantTip tip = widget.tip;
    final (IconData icon, Color tint) = assistantActionStyle(tip.action.type, tip.action.id);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Semantics(
      container: true,
      label: '${'did_you_know'.tr} ${tip.title}. ${tip.body}',
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint.withValues(alpha: dark ? 0.16 : 0.08), theme.cardColor),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(color: dark ? theme.cardColor : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 30, color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(child: Text('did_you_know'.tr.toUpperCase(),
                style: textBold.copyWith(fontSize: 11, letterSpacing: 0.9, color: tint))),
            const SizedBox(height: 4),
            Text(tip.title, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            if (tip.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tip.body, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.45, color: textColor.withValues(alpha: 0.72))),
            ],
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                widget.controller.dismissTip(tip);
                openAssistantAction(tip.action);
              },
              child: Text(tip.action.label, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white)),
            ),
          ])),
          IconButton(
            tooltip: 'did_you_know_hide'.tr,
            onPressed: () => widget.controller.dismissTip(tip),
            icon: Icon(Icons.close_rounded, size: 18, color: textColor.withValues(alpha: 0.55)),
          ),
        ]),
      ),
    );
  }
}

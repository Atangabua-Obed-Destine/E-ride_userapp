import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/activity/controllers/activity_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/assistant_actions.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/getting_started.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/explore/widgets/explore_widgets.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Ask E-Ride: the customer asks in their own words (typed or spoken, English,
/// French or Pidgin); each answer is a line or two and buttons into the app.
class AssistantScreen extends StatefulWidget {
  /// Asked straight away (from a help sheet's "Ask more", or the activity sheet).
  final String? question;
  /// Start listening at once (the microphone on the ask bar).
  final bool listen;
  const AssistantScreen({super.key, this.question, this.listen = false});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;
  late final AssistantController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.find<AssistantController>();
    _c.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.question != null && widget.question!.trim().isNotEmpty) {
        _send(widget.question!);
      } else if (widget.listen) {
        _toggleListening();
      }
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    _input.clear();
    final f = _c.ask(text);
    _toBottom();
    await f;
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && mounted) setState(() => _listening = false);
    });
    if (!ok) return;
    setState(() => _listening = true);
    await _speech.listen(onResult: (SpeechRecognitionResult r) {
      _input.text = r.recognizedWords;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
        setState(() => _listening = false);
        _send(r.recognizedWords);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        actions: [
          GetBuilder<AssistantController>(builder: (c) => c.messages.isEmpty ? const SizedBox() : IconButton(
                tooltip: 'assistant_new_chat'.tr,
                onPressed: c.asking ? null : c.newChat,
                icon: const Icon(Icons.add_comment_outlined),
              )),
        ],
        title: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('assistant_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
            Text('assistant_languages'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
        ]),
      ),
      body: GetBuilder<AssistantController>(builder: (c) {
        return Column(children: [
          Expanded(child: c.messages.isEmpty
              ? _Suggestions(onPick: _send)
              : ListView(controller: _scroll, padding: const EdgeInsets.all(14), children: [
                  for (int i = 0; i < c.messages.length; i++)
                    c.messages[i].fromUser
                        ? _UserBubble(text: c.messages[i].text)
                        : _AnswerBubble(
                            message: c.messages[i],
                            onFeedback: (h) => c.feedback(c.messages[i], h),
                            // Next questions only under the last answer.
                            onFollowUp: (i == c.messages.length - 1 && !c.asking) ? _send : null,
                          ),
                  if (c.asking) const _Typing(),
                ])),
          Container(
            color: theme.cardColor,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: _listening ? 'assistant_listening'.tr : 'assistant_hint'.tr,
                    filled: true,
                    fillColor: theme.hintColor.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                )),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _input,
                  builder: (_, v, __) {
                    final typing = v.text.trim().isNotEmpty && !_listening;
                    return Material(
                      color: theme.primaryColor,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: typing ? 'assistant_send'.tr : 'assistant_speak'.tr,
                        onPressed: c.asking ? null : (typing ? () => _send(_input.text) : _toggleListening),
                        icon: Icon(typing ? Icons.arrow_upward_rounded : (_listening ? Icons.stop_rounded : Icons.mic_none_rounded), color: Colors.white),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 6),
              Text('assistant_disclaimer'.tr, textAlign: TextAlign.center,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: theme.hintColor)),
            ]),
          ),
        ]);
      }),
    );
  }
}

/// Before the first question: hello by name, what is going on, the
/// getting-started guide for new customers, and things people often ask.
class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Suggestions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = (Get.find<ProfileController>().profileModel?.data?.firstName ?? '').trim().split(' ').first;
    final int hour = DateTime.now().hour;
    final String hello = (hour < 12 ? 'assistant_morning' : hour < 18 ? 'assistant_afternoon' : 'assistant_evening').tr;
    final bool busy = Get.isRegistered<ActivityController>() && Get.find<ActivityController>().items.isNotEmpty;
    final bool isNew = GettingStarted.isNewCustomer;
    final List<(IconData, String, List<String>)> groups = [
      (Icons.local_taxi_rounded, 'assistant_group_move'.tr, ['assistant_idea_ride'.tr, 'assistant_idea_later'.tr]),
      (Icons.inventory_2_rounded, 'assistant_group_send'.tr, ['assistant_idea_parcel'.tr, 'assistant_idea_voice'.tr]),
      (Icons.search_rounded, 'assistant_group_find'.tr, ['assistant_idea_4'.tr, 'assistant_idea_2'.tr]),
      (Icons.help_outline_rounded, 'assistant_group_help'.tr, ['assistant_idea_1'.tr, 'assistant_idea_safety'.tr]),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 20), children: [
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome_rounded, size: 24, color: theme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? 'assistant_welcome'.tr : '$hello, $name',
              style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
          Text((isNew ? 'assistant_welcome_new' : 'assistant_welcome_sub').tr,
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
        ])),
      ]),
      const SizedBox(height: 16),
      if (busy) ...[
        _Idea(icon: Icons.pending_actions_rounded, text: 'assistant_idea_activity'.tr, onPick: onPick, strong: true),
        const SizedBox(height: 14),
      ],
      if (isNew) ...[
        const GettingStartedCard(),
        const SizedBox(height: 18),
      ],
      Text('assistant_try'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
      const SizedBox(height: 8),
      for (final (IconData icon, String title, List<String> ideas) in groups) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: theme.hintColor),
            const SizedBox(width: 6),
            Text(title, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final idea in ideas) _Idea(text: idea, onPick: onPick)]),
        const SizedBox(height: 4),
      ],
      if (!isNew) ...[
        const SizedBox(height: 12),
        Center(child: TextButton.icon(
          onPressed: GettingStarted.show,
          icon: Icon(Icons.flag_rounded, size: 18, color: theme.primaryColor),
          label: Text('guide_title'.tr, style: textMedium.copyWith(color: theme.primaryColor)),
        )),
      ],
    ]);
  }
}

/// A question to ask in one tap.
class _Idea extends StatelessWidget {
  final IconData? icon;
  final String text;
  final ValueChanged<String> onPick;
  final bool strong;
  const _Idea({this.icon, required this.text, required this.onPick, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: strong ? theme.primaryColor.withValues(alpha: 0.08) : theme.cardColor,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onPick(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.primaryColor.withValues(alpha: 0.22))),
          child: Row(mainAxisSize: strong ? MainAxisSize.max : MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: theme.primaryColor), const SizedBox(width: 8)],
            Flexible(child: Text(text, style: (strong ? textBold : textMedium).copyWith(fontSize: Dimensions.fontSizeSmall + 1, color: theme.textTheme.bodyLarge?.color))),
          ]),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(2)),
        ),
        child: Text(text, style: textRegular.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeDefault, height: 1.4)),
      ),
    );
  }
}

class _AnswerBubble extends StatelessWidget {
  final AssistantMessage message;
  final ValueChanged<bool> onFeedback;
  final ValueChanged<String>? onFollowUp;
  const _AnswerBubble({required this.message, required this.onFeedback, this.onFollowUp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomRight: Radius.circular(8), bottomLeft: Radius.circular(2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.text, style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.45, color: theme.textTheme.bodyLarge?.color)),
            for (int i = 0; i < message.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22, height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: primary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(message.steps[i], style: textRegular.copyWith(fontSize: Dimensions.fontSizeDefault, height: 1.4, color: theme.textTheme.bodyLarge?.color)),
                  )),
                ]),
              ),
          ]),
        ),
        if (message.cards.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: message.cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _ResultCard(card: message.cards[i]),
            ),
          ),
        ],
        if (message.actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (int i = 0; i < message.actions.length; i++)
              _ActionButton(action: message.actions[i], filled: i == 0 && message.actions[i].type != 'support'),
          ]),
        ],
        if (onFollowUp != null && message.followUps.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final String q in message.followUps)
              Material(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onFollowUp!(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.hintColor.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(q, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                    ]),
                  ),
                ),
              ),
          ]),
        ],
        if (message.questionId != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            _Thumb(icon: Icons.thumb_up_alt_outlined, on: message.helped == true, color: const Color(0xFF12A150), tooltip: 'assistant_helped'.tr,
                onTap: message.helped == null ? () => onFeedback(true) : null),
            const SizedBox(width: 4),
            _Thumb(icon: Icons.thumb_down_alt_outlined, on: message.helped == false, color: primary, tooltip: 'assistant_not_helped'.tr,
                onTap: message.helped == null ? () => onFeedback(false) : null),
            if (message.helped != null) ...[
              const SizedBox(width: 8),
              Text('assistant_thanks'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
            ],
          ]),
        ],
      ]),
    );
  }
}

/// One thing E-Ride has: photo or icon, what it is, where, the price.
class _ResultCard extends StatelessWidget {
  final AssistantCard card;
  const _ResultCard({required this.card});

  static (IconData, String) _look(String type) => switch (type) {
        'market_item' || 'market_shop' => (Icons.storefront_rounded, 'market'),
        'store' => (Icons.restaurant_rounded, 'restaurant'),
        'place' || 'tour' => (Icons.landscape_rounded, 'landmark'),
        'job' => (Icons.work_outline_rounded, 'bank'),
        'listing' => (Icons.home_work_rounded, 'home'),
        'bus' => (Icons.directions_bus_rounded, 'bus'),
        _ => (Icons.place_rounded, 'place'),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String colourKey) = _look(card.type);
    final Color tint = ExploreIcons.color(colourKey);
    return SizedBox(
      width: 150,
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          onTap: () => openAssistantCard(card),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 84,
              width: double.infinity,
              child: card.photo != null
                  ? Image.network(card.photo!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: tint.withValues(alpha: 0.12), child: Icon(icon, color: tint, size: 30)))
                  : Container(color: tint.withValues(alpha: 0.12), child: Icon(icon, color: tint, size: 30)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, height: 1.2, color: theme.textTheme.bodyLarge?.color)),
                if (card.subtitle.isNotEmpty)
                  Text(card.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
                if (card.price != null && card.price! > 0)
                  Text(PriceConverter.convertPrice(card.price!), style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AssistantAction action;
  final bool filled;
  const _ActionButton({required this.action, required this.filled});

  @override
  Widget build(BuildContext context) {
    final support = action.type == 'support';
    final color = support ? const Color(0xFF128C4A) : Theme.of(context).primaryColor;
    return Material(
      color: filled ? color : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: color, width: 1.5)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        onTap: () => openAssistantAction(action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(assistantActionIcon(action.type), size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(action.label, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: filled ? Colors.white : color)),
          ]),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final IconData icon;
  final bool on;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _Thumb({required this.icon, required this.on, required this.color, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(on ? (icon == Icons.thumb_up_alt_outlined ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded) : icon,
          size: 18, color: on ? color : theme.hintColor),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)),
          const SizedBox(width: 10),
          Text('assistant_thinking'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ]),
      ),
    );
  }
}

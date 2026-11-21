import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/market/domain/services/market_service_interface.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Tags while posting on the Market: the other words buyers might search for.
///
/// Suggestions come from the server as the title changes (other names for the
/// same thing in English, French and Pidgin, the category's words, what other
/// sellers use), with what people looked for this week and did not find.
/// Optional, but nudged: a small "how findable" bar fills up from 3 tags.
class MarketTagsField extends StatefulWidget {
  final List<String> initial;
  final TextEditingController title;
  final String? Function() category;
  final String? Function() serviceKind;
  final ValueChanged<List<String>> onChanged;

  const MarketTagsField({super.key, required this.initial, required this.title, required this.category, required this.serviceKind, required this.onChanged});

  static const int max = 8;
  static const int good = 3;

  /// The same cleaning as the server: lower case, no "#", letters, digits, spaces, "-" and "+".
  static String? clean(String raw) {
    String t = raw.trim().toLowerCase().replaceAll('#', '');
    t = t.replaceAll(RegExp(r'[^\p{L}\p{N}\s\-+]', unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length >= 2 && t.length <= 24 ? t : null;
  }

  @override
  State<MarketTagsField> createState() => _MarketTagsFieldState();
}

class _MarketTagsFieldState extends State<MarketTagsField> {
  late final List<String> _tags = [...widget.initial];
  final TextEditingController _input = TextEditingController();
  List<String> _suggested = [];
  List<({String term, int count})> _wanted = [];
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.title.addListener(_titleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    widget.title.removeListener(_titleChanged);
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _titleChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _load);
  }

  Future<void> _load({bool force = false}) async {
    final String title = widget.title.text.trim();
    final String query = '$title|${widget.category() ?? ''}|${widget.serviceKind() ?? ''}|${_tags.join(',')}';
    if (!force && query == _lastQuery) return;
    _lastQuery = query;
    if (title.length < 3 && widget.category() == null && widget.serviceKind() == null) {
      if (mounted) setState(() => _suggested = []);
      return;
    }
    final Response r = await Get.find<MarketServiceInterface>().getTagSuggestions({
      'title': title,
      if (widget.category() != null) 'category': widget.category(),
      if (widget.serviceKind() != null) 'service_kind': widget.serviceKind(),
      if (_tags.isNotEmpty) 'tags': _tags.join(','),
    });
    if (!mounted || r.statusCode != 200 || r.body is! Map || r.body['data'] is! Map) return;
    final Map d = r.body['data'];
    setState(() {
      _suggested = ((d['suggested'] as List?) ?? []).map((e) => '$e').where((t) => !_tags.contains(t)).toList();
      _wanted = ((d['wanted'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => (term: '${e['term']}', count: int.tryParse('${e['count']}') ?? 0))
          .where((w) => w.count > 0)
          .toList();
    });
  }

  void _add(String raw) {
    final String? t = MarketTagsField.clean(raw);
    if (t == null || _tags.contains(t) || _tags.length >= MarketTagsField.max) return;
    setState(() {
      _tags.add(t);
      _suggested.remove(t);
    });
    widget.onChanged(List.of(_tags));
  }

  void _remove(String t) {
    setState(() => _tags.remove(t));
    widget.onChanged(List.of(_tags));
  }

  void _submitInput() {
    for (final String part in _input.text.split(RegExp(r'[,;\n]'))) {
      _add(part);
    }
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool full = _tags.length >= MarketTagsField.max;
    final double level = (_tags.length / MarketTagsField.good).clamp(0.0, 1.0);
    final Color barColor = _tags.length >= MarketTagsField.good ? const Color(0xFF15803D) : const Color(0xFFF59E0B);
    final List<String> suggestions = _suggested.where((t) => !_tags.contains(t)).take(10).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('market_tags'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
      const SizedBox(height: 2),
      Text('market_tags_hint'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.35)),
      const SizedBox(height: Dimensions.paddingSizeSmall),

      // How findable the post is: full from 3 tags.
      Row(children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: level, minHeight: 6, backgroundColor: theme.hintColor.withValues(alpha: 0.15), color: barColor),
        )),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Text(_tags.length >= MarketTagsField.good ? 'market_tags_good'.tr : 'market_tags_more'.trParams({'n': '${MarketTagsField.good - _tags.length}'}),
            style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: barColor)),
      ]),
      const SizedBox(height: Dimensions.paddingSizeSmall),

      if (_tags.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final String t in _tags)
            InputChip(
              label: Text(t),
              onDeleted: () => _remove(t),
              deleteButtonTooltipMessage: 'market_tag_remove'.tr,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              backgroundColor: theme.primaryColor.withValues(alpha: 0.08),
              side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3)),
              labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color),
            ),
        ]),
      const SizedBox(height: Dimensions.paddingSizeSmall),

      TextField(
        controller: _input,
        enabled: !full,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitInput(),
        onChanged: (v) {
          if (v.contains(',')) _submitInput();
        },
        decoration: InputDecoration(
          hintText: full ? 'market_tags_full'.tr : 'market_tag_add_hint'.tr,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'market_tag_add'.tr, onPressed: full ? null : _submitInput),
        ),
      ),

      if (suggestions.isNotEmpty && !full) ...[
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('market_tags_suggested'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final String t in suggestions)
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16, color: theme.primaryColor),
              label: Text(t),
              onPressed: () => _add(t),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: theme.hintColor.withValues(alpha: 0.3)),
              labelStyle: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color),
            ),
        ]),
      ],

      // What buyers looked for this week and did not find.
      if (_wanted.isNotEmpty) ...[
        const SizedBox(height: Dimensions.paddingSize),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(6)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.trending_up_rounded, size: 18, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text('market_people_looking'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF92400E))),
            ]),
            const SizedBox(height: 4),
            for (final w in _wanted)
              InkWell(
                onTap: full ? null : () => _add(w.term),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('market_people_looking_line'.trParams({'term': w.term, 'n': '${w.count}'}),
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF92400E)))),
                    if (!_tags.contains(w.term) && !full)
                      Text('market_tag_add'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }
}

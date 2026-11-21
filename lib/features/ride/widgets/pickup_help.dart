import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/features/assistant/controllers/assistant_controller.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/models/assistant_models.dart';
import 'package:ride_sharing_user_app/features/assistant/widgets/getting_started.dart';
import 'package:ride_sharing_user_app/features/location/controllers/location_controller.dart';
import 'package:ride_sharing_user_app/features/location/domain/models/prediction_model.dart';
import 'package:ride_sharing_user_app/features/parcel/controllers/parcel_controller.dart';
import 'package:ride_sharing_user_app/features/ride/controllers/ride_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Help your driver find you. Addresses here are landmarks ("back of Total
/// Nkwen, blue gate"), so the customer says where they are: written, or as a
/// voice note in Pidgin, English or French. The driver hears the note when the
/// request rings and on the way, with the words written under it. When E-Ride
/// can read the note, it also fills the pickup description and the destination.

String voiceDuration(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// On Trip Setup, under the pickup: what the driver will get, or an invitation to add it.
class PickupHelpRow extends StatelessWidget {
  const PickupHelpRow({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<RideController>(builder: (ride) {
      final String note = ride.pickupNoteText;
      final VoiceTripResult? voice = ride.voiceNote;
      if (!ride.hasPickupHelp) {
        return Material(
          color: theme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => PickupHelpSheet.show(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                Icon(Icons.record_voice_over_rounded, size: 20, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('pickup_help_title'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  Text('pickup_help_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
                ])),
                Icon(Icons.mic_rounded, size: 18, color: theme.primaryColor),
              ]),
            ),
          ),
        );
      }
      return Material(
        color: const Color(0xFF15803D).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => PickupHelpSheet.show(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF15803D))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('pickup_help_ready'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF15803D))),
                if (note.isNotEmpty)
                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
                if (voice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: VoiceNotePlayer(localPath: voice.localPath, url: voice.url, seconds: voice.seconds, compact: true),
                  ),
              ])),
              Text('pickup_help_change'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
            ]),
          ),
        ),
      );
    });
  }
}

class PickupHelpSheet {
  /// [asking]: shown by "Proceed" when nothing tells the driver where to
  /// find the customer; true means go on (Continue or Skip), null stay.
  static Future<bool?> show({bool asking = false}) => Get.bottomSheet<bool>(
        _PickupHelpBody(asking: asking),
        isScrollControlled: true,
        backgroundColor: Get.theme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      );
}

class _PickupHelpBody extends StatelessWidget {
  final bool asking;
  const _PickupHelpBody({required this.asking});

  void _done(bool go) {
    final RideController ride = Get.find<RideController>();
    ride.setPickupNote();
    ride.pickupHelpAsked = true;
    if (ride.hasPickupHelp) GettingStarted.markPickupDone();
    Get.back(result: go);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RideController ride = Get.find<RideController>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text((asking ? 'pickup_help_ask_title' : 'pickup_help_title').tr,
                style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text('pickup_help_ask_sub'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
            const SizedBox(height: 16),

            const VoiceNoteRecorder(kind: 'ride'),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: Divider(color: theme.hintColor.withValues(alpha: 0.25))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('pickup_help_or_write'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))),
              Expanded(child: Divider(color: theme.hintColor.withValues(alpha: 0.25))),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: ride.pickupNoteController,
              minLines: 2,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'pickup_help_write_hint'.tr,
                hintStyle: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor),
                filled: true,
                fillColor: theme.hintColor.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              if (asking) ...[
                Expanded(child: OutlinedButton(
                  onPressed: () => _done(true),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  child: Text('pickup_help_skip'.tr),
                )),
                const SizedBox(width: 10),
              ],
              Expanded(child: ElevatedButton(
                onPressed: () => _done(true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48), backgroundColor: theme.primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text((asking ? 'pickup_help_continue' : 'save').tr, style: textBold.copyWith(color: Colors.white)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

enum _Rec { idle, recording, sending }

/// Records a voice note for the driver, sends it, and shows what E-Ride heard.
/// [kind] ride or parcel. On a ride, the place they go fills the destination;
/// on a parcel, the receiver, weight and kind of parcel fill in.
class VoiceNoteRecorder extends StatefulWidget {
  final String kind;
  /// A smaller look, inside a form (the parcel's sender details).
  final bool compact;
  const VoiceNoteRecorder({super.key, required this.kind, this.compact = false});

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  static const int maxSeconds = 60;
  final AudioRecorder _recorder = AudioRecorder();
  _Rec _state = _Rec.idle;
  int _seconds = 0;
  double _level = 0;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amp;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _amp?.cancel();
    if (_state == _Rec.recording) _recorder.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      showCustomSnackBar('voice_note_mic_needed'.tr);
      return;
    }
    final Directory dir = await getTemporaryDirectory();
    // AAC in .m4a, like chat voice messages: small, and plays everywhere (driver app, admin).
    _path = '${dir.path}/pickup_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 16000, numChannels: 1),
      path: _path!,
    );
    _amp = _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
      if (mounted) setState(() => _level = ((a.current + 50) / 50).clamp(0.0, 1.0));
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= maxSeconds) _stop();
    });
    setState(() {
      _state = _Rec.recording;
      _seconds = 0;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _amp?.cancel();
    await _recorder.stop();
    if (_path != null) File(_path!).delete().catchError((_) => File(_path!));
    if (mounted) setState(() => _state = _Rec.idle);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _amp?.cancel();
    final String? path = await _recorder.stop();
    if (!mounted) return;
    if (path == null || _seconds < 1) {
      setState(() => _state = _Rec.idle);
      showCustomSnackBar('voice_note_too_short'.tr);
      return;
    }
    setState(() => _state = _Rec.sending);
    final List<String> categories = widget.kind == 'parcel'
        ? [for (final c in Get.find<ParcelController>().parcelCategoryList ?? const []) if ((c.name ?? '').isNotEmpty) c.name!]
        : const [];
    final VoiceTripResult? r = await Get.find<AssistantController>().voiceTrip(path, _seconds, widget.kind, categories: categories);
    if (!mounted) return;
    setState(() => _state = _Rec.idle);
    if (r == null) {
      showCustomSnackBar('voice_note_failed'.tr);
      return;
    }
    final RideController ride = Get.find<RideController>();
    ride.setVoiceNote(r);
    GettingStarted.markPickupDone();
    // What E-Ride heard about the pickup becomes the written note (unless one was written), for the driver to read too.
    ride.usePickupText(r.driverText);
    if (widget.kind == 'parcel' && r.parcel != null) _fillParcel(r.parcel!);
  }

  /// The parcel's receiver, weight and kind, where the customer has not filled them yet.
  void _fillParcel(VoiceParcel p) {
    final ParcelController parcel = Get.find<ParcelController>();
    if (p.receiverName.isNotEmpty && parcel.receiverNameController.text.trim().isEmpty) parcel.receiverNameController.text = p.receiverName;
    String phone = p.receiverPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('237') && phone.length == 12) phone = phone.substring(3);
    if (phone.length == 9 && parcel.receiverContactController.text.trim().isEmpty) parcel.receiverContactController.text = phone;
    if (p.weightKg != null && parcel.parcelWeightController.text.trim().isEmpty) {
      parcel.parcelWeightController.text = p.weightKg! == p.weightKg!.roundToDouble() ? '${p.weightKg!.round()}' : '${p.weightKg}';
    }
    final int index = (parcel.parcelCategoryList ?? const []).indexWhere((c) => c.name == p.category);
    if (index >= 0) parcel.updateParcelCategoryIndex(index);
    parcel.update();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GetBuilder<RideController>(builder: (ride) {
      final VoiceTripResult? note = ride.voiceNote;
      if (_state == _Rec.recording) return _recording(theme);
      if (_state == _Rec.sending) return _sending(theme);
      if (note != null) return _done(theme, ride, note);
      return _idle(theme);
    });
  }

  Widget _idle(ThemeData theme) {
    if (widget.compact) {
      return OutlinedButton.icon(
        onPressed: _start,
        icon: Icon(Icons.mic_rounded, color: theme.primaryColor),
        label: Text('voice_note_record'.tr, style: textBold.copyWith(color: theme.primaryColor, fontSize: Dimensions.fontSizeSmall)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Semantics(
          button: true,
          label: 'voice_note_record'.tr,
          child: Material(
            color: theme.primaryColor,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _start,
              child: const SizedBox(width: 68, height: 68, child: Icon(Icons.mic_rounded, color: Colors.white, size: 34)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('voice_note_record'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 4),
        Text((widget.kind == 'parcel' ? 'voice_note_examples_parcel' : 'voice_note_examples').tr, textAlign: TextAlign.center,
            style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
      ]),
    );
  }

  Widget _recording(ThemeData theme) {
    const Color red = Color(0xFFE02020);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 10 : 14),
      decoration: BoxDecoration(color: red.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6), border: Border.all(color: red.withValues(alpha: 0.3))),
      child: Row(children: [
        // Grows with the voice, so the customer sees the phone hears them.
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44, height: 44,
          decoration: BoxDecoration(color: red.withValues(alpha: 0.15 + _level * 0.35), shape: BoxShape.circle),
          child: const Icon(Icons.mic_rounded, color: red),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('voice_note_recording'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: red)),
          Text('${voiceDuration(_seconds)} / ${voiceDuration(maxSeconds)}',
              style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
        ])),
        TextButton(onPressed: _cancel, child: Text('cancel'.tr, style: textMedium.copyWith(color: theme.hintColor))),
        ElevatedButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
          label: Text('voice_note_done'.tr, style: textBold.copyWith(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        ),
      ]),
    );
  }

  Widget _sending(ThemeData theme) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)),
          const SizedBox(width: 12),
          Expanded(child: Text('voice_note_listening'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
        ]),
      );

  Widget _done(ThemeData theme, RideController ride, VoiceTripResult note) {
    final LocationController location = Get.find<LocationController>();
    // Nothing in the field yet (the controller's own address can be left over from an earlier booking).
    final bool needsPlace = note.destination.isNotEmpty &&
        (widget.kind == 'parcel'
            ? Get.find<ParcelController>().receiverAddressController.text.trim().isEmpty
            : location.destinationLocationController.text.trim().isEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: VoiceNotePlayer(localPath: note.localPath, url: note.url, seconds: note.seconds)),
          IconButton(
            tooltip: 'voice_note_delete'.tr,
            onPressed: () => ride.setVoiceNote(null),
            icon: Icon(Icons.delete_outline_rounded, color: theme.hintColor),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.hearing_rounded, size: 15, color: Color(0xFF15803D)),
          const SizedBox(width: 6),
          Expanded(child: Text('voice_note_driver_hears'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF15803D)))),
        ]),
        if (note.understood && note.transcript.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('voice_note_heard'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: theme.hintColor)),
          const SizedBox(height: 2),
          Text('"${note.transcript}"', style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, fontStyle: FontStyle.italic, height: 1.4,
              color: theme.textTheme.bodyLarge?.color)),
        ] else if (!note.understood) ...[
          const SizedBox(height: 6),
          Text('voice_note_not_read'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor, height: 1.4)),
        ],
        if (needsPlace) VoicePlaceSuggestions(text: note.destination, parcel: widget.kind == 'parcel'),
        TextButton.icon(
          onPressed: () {
            ride.setVoiceNote(null);
            _start();
          },
          icon: Icon(Icons.mic_none_rounded, size: 18, color: theme.primaryColor),
          label: Text('voice_note_again'.tr, style: textMedium.copyWith(color: theme.primaryColor, fontSize: Dimensions.fontSizeSmall)),
        ),
      ]),
    );
  }
}

/// "Going to Up Station?": the places that match what the customer said, to pick one.
class VoicePlaceSuggestions extends StatefulWidget {
  final String text;
  final bool parcel;
  const VoicePlaceSuggestions({super.key, required this.text, this.parcel = false});

  @override
  State<VoicePlaceSuggestions> createState() => _VoicePlaceSuggestionsState();
}

class _VoicePlaceSuggestionsState extends State<VoicePlaceSuggestions> {
  List<Suggestions>? _places;
  bool _setting = false;
  String? _chosen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final LocationController location = Get.find<LocationController>();
      final List<Suggestions>? found = await location.searchLocation(context, widget.text,
          type: widget.parcel ? LocationType.receiverLocation : LocationType.to, fromMap: true);
      if (mounted) setState(() => _places = (found ?? const []).take(3).toList());
    });
  }

  Future<void> _pick(Suggestions s) async {
    final String id = s.placePrediction?.placeId ?? '';
    final String name = s.placePrediction?.text?.text ?? widget.text;
    if (id.isEmpty) return;
    setState(() => _setting = true);
    final LocationController location = Get.find<LocationController>();
    final Address? a = await location.setLocation(id, name, null, type: widget.parcel ? LocationType.receiverLocation : LocationType.to, fromSearch: true);
    if (widget.parcel && a != null) location.setReceiverAddress(a);
    if (mounted) {
      setState(() {
        _setting = false;
        if (a != null) _chosen = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_chosen != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 6),
          Expanded(child: Text('voice_place_set'.trParams({'place': _chosen!}),
              style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: const Color(0xFF15803D)))),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((widget.parcel ? 'voice_place_parcel' : 'voice_place_ride').trParams({'place': widget.text}),
            style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 6),
        if (_places == null || _setting)
          SizedBox(height: 24, child: Align(alignment: Alignment.centerLeft,
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))))
        else if (_places!.isEmpty)
          Text('voice_place_none'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor))
        else
          for (final Suggestions s in _places!)
            Material(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _pick(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  child: Row(children: [
                    Icon(Icons.place_rounded, size: 18, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.placePrediction?.text?.text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color))),
                    Text('voice_place_use'.tr, style: textBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.primaryColor)),
                  ]),
                ),
              ),
            ),
      ]),
    );
  }
}

/// Plays a voice note: from the phone when it was recorded here, else from the server.
class VoiceNotePlayer extends StatefulWidget {
  final String? localPath;
  final String? url;
  final int seconds;
  final bool compact;
  const VoiceNotePlayer({super.key, this.localPath, this.url, required this.seconds, this.compact = false});

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _at = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPositionChanged.listen((d) { if (mounted) setState(() => _at = d); }));
    _subs.add(_player.onPlayerComplete.listen((_) { if (mounted) setState(() { _playing = false; _at = Duration.zero; }); }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      if (_at > Duration.zero) {
        await _player.resume();
      } else if (widget.localPath != null && File(widget.localPath!).existsSync()) {
        await _player.play(DeviceFileSource(widget.localPath!));
      } else if ((widget.url ?? '').isNotEmpty) {
        await _player.play(UrlSource(widget.url!));
      }
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double total = widget.seconds <= 0 ? 1 : widget.seconds.toDouble();
    final double progress = (_at.inMilliseconds / 1000 / total).clamp(0.0, 1.0);
    final double size = widget.compact ? 30 : 40;
    return Row(children: [
      Material(
        color: theme.primaryColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: SizedBox(width: size, height: size,
              child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: size * 0.6)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('voice_note_label'.tr, style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: progress, minHeight: 4, color: theme.primaryColor, backgroundColor: theme.hintColor.withValues(alpha: 0.2)),
        ),
      ])),
      const SizedBox(width: 10),
      Text(voiceDuration(_playing || _at > Duration.zero ? _at.inSeconds : widget.seconds),
          style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
    ]);
  }
}

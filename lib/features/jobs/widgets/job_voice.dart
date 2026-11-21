import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// The voice intro is at most 30 seconds.
const int jobVoiceMaxSeconds = 30;

String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Plays a voice intro: from the server ([url]) or a fresh recording ([path]).
class JobVoicePlayer extends StatefulWidget {
  final String? url;
  final String? path;
  final int? seconds;
  /// Light text on a dark card.
  final bool onDark;
  final bool compact;
  const JobVoicePlayer({super.key, this.url, this.path, this.seconds, this.onDark = false, this.compact = false});

  @override
  State<JobVoicePlayer> createState() => _JobVoicePlayerState();
}

class _JobVoicePlayerState extends State<JobVoicePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPositionChanged.listen((p) => mounted ? setState(() => _position = p) : null));
    _subs.add(_player.onDurationChanged.listen((d) => mounted ? setState(() => _duration = d) : null));
    _subs.add(_player.onPlayerComplete.listen((_) => mounted ? setState(() {
          _playing = false;
          _position = Duration.zero;
        }) : null));
  }

  @override
  void didUpdateWidget(covariant JobVoicePlayer old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.url != widget.url) {
      _player.stop();
      _playing = false;
      _position = Duration.zero;
      _duration = null;
    }
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
    setState(() => _loading = true);
    try {
      if (_position > Duration.zero) {
        await _player.resume();
      } else if (widget.path != null) {
        await _player.play(DeviceFileSource(widget.path!));
      } else if (widget.url != null) {
        await _player.play(UrlSource(widget.url!));
      }
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      showCustomSnackBar('jobs_voice_play_failed'.tr);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = widget.onDark ? Colors.white : theme.primaryColor;
    final total = _duration?.inSeconds ?? widget.seconds ?? 0;
    final progress = total > 0 ? (_position.inMilliseconds / (total * 1000)).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: widget.compact ? 2 : 4),
      decoration: BoxDecoration(
        color: widget.onDark ? Colors.white.withValues(alpha: 0.1) : theme.primaryColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: _playing ? 'jobs_voice_pause'.tr : 'jobs_voice_play'.tr,
          onPressed: _loading ? null : _toggle,
          icon: _loading
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: fg),
        ),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: progress, minHeight: 4, color: fg, backgroundColor: fg.withValues(alpha: 0.2)),
        )),
        const SizedBox(width: 10),
        Text(_clock(_playing || _position > Duration.zero ? _position.inSeconds : total),
            style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: widget.onDark ? Colors.white : theme.textTheme.bodyLarge?.color)),
        const SizedBox(width: 6),
      ]),
    );
  }
}

/// Records the voice intro on the Work Card: up to 30 seconds, stops by itself, listen, record again or remove.
/// [onRecorded] gets the file and its length; [onRemove] drops the saved one.
class JobVoiceRecorder extends StatefulWidget {
  final String? savedUrl;
  final int? savedSeconds;
  final void Function(String path, int seconds) onRecorded;
  final VoidCallback onRemove;
  const JobVoiceRecorder({super.key, this.savedUrl, this.savedSeconds, required this.onRecorded, required this.onRemove});

  @override
  State<JobVoiceRecorder> createState() => _JobVoiceRecorderState();
}

class _JobVoiceRecorderState extends State<JobVoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _elapsed = 0;
  Timer? _timer;
  String? _path;
  int? _seconds;
  bool _removed = false;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      showCustomSnackBar('microphone_permission'.tr);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/work_card_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000), path: path);
    setState(() {
      _recording = true;
      _elapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= jobVoiceMaxSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    final seconds = _elapsed.clamp(1, jobVoiceMaxSeconds);
    setState(() => _recording = false);
    if (path == null || !await File(path).exists()) return;
    if (_elapsed < 3) {
      showCustomSnackBar('jobs_voice_too_short'.tr);
      return;
    }
    setState(() {
      _path = path;
      _seconds = seconds;
      _removed = false;
    });
    widget.onRecorded(path, seconds);
  }

  void _remove() {
    setState(() {
      _path = null;
      _seconds = null;
      _removed = true;
    });
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final hasSaved = !_removed && widget.savedUrl != null;
    final hasAny = _path != null || hasSaved;
    if (_recording) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.fiber_manual_record_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('jobs_voice_recording'.tr, style: textSemiBold.copyWith(color: textColor)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
                value: _elapsed / jobVoiceMaxSeconds, minHeight: 4, color: theme.colorScheme.error,
                backgroundColor: theme.colorScheme.error.withValues(alpha: 0.2))),
          ])),
          const SizedBox(width: 10),
          Text('${_clock(_elapsed)} / ${_clock(jobVoiceMaxSeconds)}', style: textMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: textColor)),
          const SizedBox(width: 6),
          FilledButton(onPressed: _stop, child: Text('jobs_voice_stop'.tr)),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (hasAny) ...[
        JobVoicePlayer(path: _path, url: _path == null ? widget.savedUrl : null, seconds: _seconds ?? widget.savedSeconds),
        const SizedBox(height: 6),
      ],
      Row(children: [
        OutlinedButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.mic_none_rounded),
          label: Text(hasAny ? 'jobs_voice_again'.tr : 'jobs_voice_record'.tr),
        ),
        if (hasAny) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: _remove, child: Text('jobs_voice_remove'.tr, style: textMedium.copyWith(color: theme.colorScheme.error))),
        ],
      ]),
    ]);
  }
}

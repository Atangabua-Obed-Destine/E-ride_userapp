import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ride_sharing_user_app/common_widgets/chat_kit.dart';
import 'package:ride_sharing_user_app/common_widgets/popup_banner/popup_banner.dart';
import 'package:ride_sharing_user_app/features/message/domain/models/message_model.dart';
import 'package:ride_sharing_user_app/helper/date_converter.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/localization/localization_controller.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/config_controller.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';

bool _isAudioFile(String? fileType) {
  return fileType != null && AppConstants.allowedAudioExtensionsForFile.contains(fileType.toLowerCase());
}

class ConversationBubble extends StatefulWidget {
  final Message message;
  final Message? previousMessage;
  final int index;
  final int length;
  /// Called when a message that failed to send is tapped.
  final VoidCallback? onRetry;
  const ConversationBubble({super.key,  required this.message, this.previousMessage, required this.index, required this.length, this.onRetry});

  @override
  State<ConversationBubble> createState() => _ConversationBubbleState();
}

class _ConversationBubbleState extends State<ConversationBubble> {
  List<String> images = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    images = [];
    bool isMe = widget.message.user?.id == Get.find<ProfileController>().profileModel?.data?.id ;
    final List<ConversationFiles> audioFiles = widget.message.conversationFiles!.where((file) => _isAudioFile(file.fileType)).toList();
    final List<ConversationFiles> otherFiles = widget.message.conversationFiles!.where((file) => !_isAudioFile(file.fileType)).toList();
    for (var element in otherFiles) {
      images.add('${Get.find<ConfigController>().config!.imageBaseUrl!.conversation}/${element.fileName ?? ''}');
    }
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: isMe ?
          const EdgeInsets.fromLTRB(20, 5,10, 4) :
          const EdgeInsets.fromLTRB(10, 5, 20, 4),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              const SizedBox(height: Dimensions.paddingSizeDefault),

              if((widget.length-1 == widget.index))...[
                Center(child: Text(
                  "${DateConverter.stringToLocalDateOnly(widget.message.createdAt ?? DateTime.now().toString())}, "
                      "${'trip'.tr}# ${widget.index==0 ? widget.message.tripId : widget.previousMessage?.tripId}",
                  style: TextStyle(color: Theme.of(context).hintColor),
                )),

                const SizedBox(height: Dimensions.paddingSizeDefault)
              ],

              Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  isMe ? const SizedBox() :
                  ClipRRect(borderRadius: BorderRadius.circular(50),
                    child: ImageWidget(height: 30, width: 30,
                      image: '${Get.find<ConfigController>().config?.imageBaseUrl!.profileImageDriver}/'
                          '${widget.message.user?.profileImage ?? ''}',
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeSmall),

                  Flexible(child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end:CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                    if(widget.message.message != null)
                      Flexible(child: Padding(
                        padding: isMe ?
                        EdgeInsets.only(left:Get.width *0.15 ) :
                        EdgeInsets.only(right:Get.width *0.1),
                        child: GestureDetector(
                          onTap: widget.message.isFailed ? widget.onRetry : null,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: widget.message.isPending ? 0.75 : 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isMe ?
                                Theme.of(context).primaryColor :
                                (Get.isDarkMode ? const Color(0xFF2C2C2E) : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 6),
                                  bottomRight: Radius.circular(isMe ? 6 : 18),
                                ),
                                boxShadow: isMe ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child:  Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Text(
                                  widget.message.message??'',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : (Get.isDarkMode ? Colors.white : const Color(0xFF1C1C1E)),
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )),

                    audioFiles.isNotEmpty ?
                    Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: audioFiles.map((file) => Padding(
                        padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
                        child: AudioMessageBubble(
                          url: '${Get.find<ConfigController>().config!.imageBaseUrl!.conversation}/${file.fileName ?? ''}',
                          fileName: file.fileName ?? 'voice_message.m4a',
                        ),
                      )).toList(),
                    ) :
                    const SizedBox.shrink(),

                    otherFiles.isNotEmpty ?
                    SizedBox(
                      width: otherFiles.length < 4 ?
                      context.width : context.width *0.6,
                      child: Directionality(
                        textDirection:Get.find<LocalizationController>().isLtr ?
                        isMe ?
                        TextDirection.rtl :
                        TextDirection.ltr :
                        isMe ?
                        TextDirection.ltr :
                        TextDirection.rtl,
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            childAspectRatio: 1,
                            crossAxisCount:otherFiles.length < 4 ? 3 : 2,
                            mainAxisSpacing: Dimensions.paddingSizeSmall,
                            crossAxisSpacing: Dimensions.paddingSizeSmall,
                          ),
                          padding: const EdgeInsets.only(top: Dimensions.paddingSizeExtraSmall),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: otherFiles.length < 4 ?
                          otherFiles.length : 4,
                          itemBuilder: (BuildContext context, index) {
                            bool isImage = otherFiles[index].fileType!.toLowerCase() == 'png'
                                || otherFiles[index].fileType!.toLowerCase() == 'jpg'
                                || otherFiles[index].fileType!.toLowerCase() == 'jpeg';
                            return isImage ?
                            Padding(
                              padding: const EdgeInsets.only(right: 5,top: 0,bottom: 5),
                              child: InkWell(
                                onTap: ()=> PopupBanner(
                                  context: context, images: images,showDownloadButton: false,
                                  initIndex: index,dotsAlignment: Alignment.bottomCenter,
                                  onClick: (index){},
                                  autoSlide: false,fit: BoxFit.contain,
                                ).show(),
                                child: Stack(children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(5),
                                    child:ImageWidget(height: 100, width: 100, fit: BoxFit.cover,
                                      image: '${Get.find<ConfigController>().config!.imageBaseUrl!.conversation!}/'
                                          '${otherFiles[index].fileName ?? ''}',
                                    ),
                                  ),

                                  (otherFiles.length > 4 && index == 3) ?
                                  Container(
                                    height: 100,
                                    width: 100,
                                    color: Colors.transparent.withValues(alpha:0.5,),
                                    child: Center(child: Text(
                                      '+${otherFiles.length - 4}',
                                      style: textRegular.copyWith(
                                        color: Theme.of(context).cardColor, fontSize: 16,
                                      ),
                                    )),
                                  ) :
                                  const SizedBox()
                                ]),
                              ),
                            ) :
                            InkWell(
                              onTap : () async {
                                final status = await Permission.storage.request();
                                if(status.isGranted){
                                  Directory? directory = Directory('/storage/emulated/0/Download');
                                  if (!await directory.exists()) {
                                    directory = Platform.isAndroid ?
                                    await getExternalStorageDirectory() :
                                    await getApplicationSupportDirectory();
                                  }
                                }
                              },
                              child: Container(height: 50,width: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context).hoverColor,
                                ),
                                child: Stack(children: [
                                  Center(child: SizedBox(width: 50, child: Image.asset(Images.folder))),

                                  Center(child: Text(
                                    '${otherFiles[index].fileName}'.substring(
                                      otherFiles[index].fileName!.length-7,
                                    ),
                                    maxLines: 5, overflow: TextOverflow.clip,
                                  )),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ) :
                    const SizedBox.shrink(),

                  ],
                  )),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: isMe ?
          const EdgeInsets.fromLTRB(5, 0, 10, 5) :
          const EdgeInsets.fromLTRB(50, 0, 5, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.message.isFailed)
              GestureDetector(
                onTap: widget.onRetry,
                child: Text(
                  'not_sent_tap_to_retry'.tr,
                  style: textRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).colorScheme.error),
                ),
              )
            else
              Text(
                widget.message.isPending ? 'sending'.tr :
                DateConverter.isoDateTimeStringToDifferentWithCurrentTime(
                  widget.message.createdAt??DateTime.now().toString(),
                ),
                textDirection: TextDirection.ltr,
                style: textRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: Theme.of(context).hintColor,
                ),
              ),
            if (isMe) ...[
              const SizedBox(width: 4),
              MessageTicks(
                pending: widget.message.isPending,
                failed: widget.message.isFailed,
                read: widget.message.isRead,
                color: Theme.of(context).hintColor,
              ),
            ],
          ]),
        ),


        if(widget.previousMessage != null && widget.previousMessage?.tripId != null && widget.message.tripId != widget.previousMessage?.tripId)
          Center(child: Text(
            "${DateConverter.stringToLocalDateOnly(widget.previousMessage?.createdAt??DateTime.now().toString())}, "
                "${'trip'.tr}# ${widget.index==0 ? widget.message.tripId : widget.previousMessage?.tripId}",
            style: TextStyle(color: Theme.of(context).hintColor),
          )),

      ],
    );
  }
}

class AudioMessageBubble extends StatefulWidget {
  final String url;
  final String fileName;
  const AudioMessageBubble({super.key, required this.url, required this.fileName});

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  static _AudioMessageBubbleState? _activePlayer;
  static const int _barCount = 20;

  final AudioPlayer _player = AudioPlayer();
  late final List<double> _barHeights;
  late final String? _mimeType;

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDownloading = false;

  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _barHeights = _generateBarHeights(widget.fileName);
    _mimeType = _mimeTypeForFileName(widget.fileName);

    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playerState = PlayerState.stopped; _position = Duration.zero; });
    });

    // iOS's AVPlayer trusts an explicit mimeType over the server's Content-Type header,
    // which some backends report incorrectly (or not at all) for audio files.
    _player.setSourceUrl(widget.url, mimeType: _mimeType).catchError((_) {});
  }

  String? _mimeTypeForFileName(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'm4a': return 'audio/mp4';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'aac': return 'audio/aac';
      case 'ogg': return 'audio/ogg';
      case 'opus': return 'audio/opus';
      case 'wma': return 'audio/x-ms-wma';
      case 'flac': return 'audio/flac';
      default: return null;
    }
  }

  List<double> _generateBarHeights(String seedKey) {
    int seed = seedKey.hashCode & 0x7fffffff;
    return List.generate(_barCount, (index) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return 0.25 + (seed % 100) / 100 * 0.75;
    });
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      if (_activePlayer != null && _activePlayer != this) {
        await _activePlayer!._player.pause();
      }
      _activePlayer = this;
      try {
        await _player.play(UrlSource(widget.url, mimeType: _mimeType));
      } catch (e) {
        showCustomSnackBar('failed_to_play_audio'.tr, isError: true);
      }
    }
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final http.Response response = await http.get(Uri.parse(widget.url));
      final Directory directory = await getApplicationDocumentsDirectory();
      final File file = File('${directory.path}/${widget.fileName}');
      await file.writeAsBytes(response.bodyBytes);
      showCustomSnackBar('file_downloaded_successfully'.tr, isError: false);
    } catch (e) {
      showCustomSnackBar('failed_to_download_file'.tr, isError: true);
    }
    if (mounted) setState(() => _isDownloading = false);
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    if (_activePlayer == this) {
      _activePlayer = null;
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _playerState == PlayerState.playing;
    final Duration displayDuration = _position > Duration.zero ? _position : _duration;
    final double progress = _duration.inMilliseconds == 0 ? 0 :
    (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    final int playedBars = (progress * _barHeights.length).round();

    return Container(
      constraints: BoxConstraints(maxWidth: Get.width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: _togglePlay,
          child: Container(
            height: 32, width: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? Theme.of(context).hintColor : Theme.of(context).primaryColor,
            ),
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        Text(_formatDuration(displayDuration), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall)),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        Flexible(child: SizedBox(
          height: 22,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barHeights.length, (index) {
                return Container(
                  width: 3,
                  height: 4 + (_barHeights[index] * 14),
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    color: index < playedBars ? Colors.teal : Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        )),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        InkWell(
          onTap: _download,
          child: _isDownloading ?
          const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) :
          Image.asset(Images.downloadIcon, height: 18, width: 18),
        ),
      ]),
    );
  }
}



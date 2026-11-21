import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/features/message/controllers/chat_inbox_controller.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/message/domain/services/message_service_interface.dart';
import 'package:ride_sharing_user_app/features/message/screens/message_screen.dart';
import 'package:ride_sharing_user_app/features/message/domain/models/channel_model.dart';
import 'package:ride_sharing_user_app/features/message/domain/models/message_model.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/file_validation_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';



class MessageController extends GetxController implements GetxService{
  final MessageServiceInterface messageServiceInterface;
  MessageController({required this.messageServiceInterface});

  List <XFile>? _pickedImageFiles =[];
  List <XFile>? get pickedImageFile => _pickedImageFiles;
  bool isLoading = false;

  FilePickerResult? _otherFile;
  FilePickerResult? get otherFile => _otherFile;

  File? _file;
  PlatformFile? objFile;
  File? get file=> _file;

  List<MultipartBody> _selectedImageList = [];
  List<MultipartBody> get selectedImageList => _selectedImageList;

  final List<dynamic> _conversationList=[];
  List<dynamic> get conversationList => _conversationList;

  final bool _paginationLoading = true;
  bool get paginationLoading => _paginationLoading;


  final String _name='';
  String get name => _name;
  final String _image='';
  String get image => _image;


  var conversationController = TextEditingController();
  final GlobalKey<FormState> conversationKey  = GlobalKey<FormState>();

  @override
  void onInit(){
    super.onInit();
    conversationController.text = '';
  }

  @override
  void onClose() {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.onClose();
  }

  bool isImagePicked = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool isRecording = false;
  Duration recordDuration = Duration.zero;
  Timer? _recordTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _recordedFilePath;
  final List<double> voiceAmplitudes = [];

  Future<void> startVoiceRecording() async {
    if (!await _audioRecorder.hasPermission()) {
      showCustomSnackBar('microphone_permission'.tr, isError: true);
      return;
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String path = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

    _recordedFilePath = path;
    isRecording = true;
    recordDuration = Duration.zero;
    voiceAmplitudes.clear();

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordDuration += const Duration(seconds: 1);
      update();
    });

    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen((amplitude) {
      voiceAmplitudes.add(amplitude.current);
      if (voiceAmplitudes.length > 20) {
        voiceAmplitudes.removeAt(0);
      }
      update();
    });

    update();
  }

  Future<void> cancelVoiceRecording() async {
    _recordTimer?.cancel();
    await _amplitudeSub?.cancel();
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    if (_recordedFilePath != null) {
      final File recordedFile = File(_recordedFilePath!);
      if (await recordedFile.exists()) {
        await recordedFile.delete();
      }
    }
    _recordedFilePath = null;
    isRecording = false;
    recordDuration = Duration.zero;
    voiceAmplitudes.clear();
    update();
  }

  Future<void> stopAndSendVoiceRecording(String channelId, String tripId) async {
    _recordTimer?.cancel();
    await _amplitudeSub?.cancel();
    final String? path = await _audioRecorder.stop();
    final String? recordedPath = path ?? _recordedFilePath;

    isRecording = false;
    recordDuration = Duration.zero;
    voiceAmplitudes.clear();
    update();

    if (recordedPath == null) {
      return;
    }

    final File recordedFile = File(recordedPath);
    final int size = await recordedFile.length();
    final PlatformFile voiceFile = PlatformFile(
      path: recordedPath,
      name: 'voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a',
      size: size,
      readStream: recordedFile.openRead(),
    );

    if (!await FileValidationHelper.validatePlatformFileSizeAsync(file: voiceFile)) {
      await recordedFile.delete();
      return;
    }

    objFile = voiceFile;
    _recordedFilePath = null;
    await sendMessage(channelId, tripId);
  }

  void pickMultipleImage(bool isRemove,{int? index}) async {
    if(isRemove) {
      if(index != null){
        _pickedImageFiles!.removeAt(index);
        _selectedImageList.removeAt(index);
      }
    }else {
      isImagePicked = true;
      Future.delayed(const Duration(seconds: 1)).then((value) {
        update();
      });
      _pickedImageFiles = await FileValidationHelper.validateAndPickMultipleImages();
      if (_pickedImageFiles != null) {
        for(int i =0; i< _pickedImageFiles!.length; i++){
          _selectedImageList.add(MultipartBody('files[$i]',_pickedImageFiles![i]));
        }
      }
      isImagePicked = false;
    }
    update();
  }

  bool permissionGranted = false;

  Future getStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      permissionGranted = true;

    } else if (await Permission.storage.request().isPermanentlyDenied) {
      await openAppSettings();
    } else if (await Permission.storage.request().isDenied) {
      await openAppSettings();
      Permission.storage.request();
    }
    update();
  }


  void pickOtherFile(bool isRemove) async {
    if(isRemove){
      _otherFile=null;
      _file = null;
    }else{
      _otherFile = await FilePicker.pickFiles(
        type: FileType.custom,
        withReadStream: true,
        allowedExtensions: AppConstants.allowedImageExtensionsForFile,
      );
      if (_otherFile != null) {
        if(await FileValidationHelper.validatePlatformFileSizeAsync(file: _otherFile!.files.single)){
          objFile = _otherFile!.files.single;
        }
      }
    }
    update();
  }

  void removeFile() async {
    _otherFile=null;
    update();
  }

  void cleanOldData(){
    _pickedImageFiles = [];
    _selectedImageList = [];
    _otherFile = null;
    _file = null;
  }



  ChannelModel? channelModel;

  Future<void> getChannelList(int offset) async{
    Response response = await messageServiceInterface.getChannelList(offset);
    if(response.statusCode == 200){
      if(offset == 1 ){
        channelModel = ChannelModel.fromJson(response.body);
      }else{
        channelModel!.totalSize =  ChannelModel.fromJson(response.body).totalSize;
        channelModel!.offset =  ChannelModel.fromJson(response.body).offset;
        channelModel!.data!.addAll(ChannelModel.fromJson(response.body).data!);
      }
      isLoading = false;
    }else{
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<void> createChannel(String userId, String? tripId) async{
    isLoading = true;
    Response response = await messageServiceInterface.createChannel(userId,tripId!);
    if(response.statusCode == 200){
      isLoading = false;
      Map map = response.body;
      String channelId = map['data']['channel']['id'];
      String tripId = map['data']['channel']['trip_id'];
      Get.to(()=> MessageScreen(channelId : channelId, tripId: tripId,userName:  '${map['data']['user']['first_name']} ${map['data']['user']['last_name']}'));
    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
  }



  MessageModel? messageModel;
  Future<void> getConversation(String channelId, int offset) async{
    isLoading = true;
    Response response = await messageServiceInterface.getConversation(channelId, offset);
    if(response.statusCode == 200){

      if(offset == 1 ){
        messageModel = MessageModel.fromJson(response.body);
      }else{
        messageModel!.totalSize =  MessageModel.fromJson(response.body).totalSize;
        messageModel!.offset =  MessageModel.fromJson(response.body).offset;
        messageModel!.data!.addAll(MessageModel.fromJson(response.body).data!);
      }
      isLoading = false;

    }else{
      isLoading = false;
      ApiChecker.checkApi(response);
    }
    update();
  }

  bool isSending = false;
  Future<void> sendMessage(String channelId , String tripId) async{
    final String pendingText = conversationController.value.text.trim();
    final bool textOnly = pendingText.isNotEmpty && _selectedImageList.isEmpty && objFile == null;
    Message? pending;
    if (textOnly && messageModel?.data != null) {
      pending = Message(
        message: pendingText,
        tripId: messageModel!.data!.isNotEmpty ? messageModel!.data!.first.tripId : null,
        user: User(id: Get.find<ProfileController>().profileModel?.data?.id),
        isPending: true,
        conversationFiles: [],
      )..createdAt = DateTime.now().toUtc().toIso8601String();
      messageModel!.data!.insert(0, pending);
    }
    isSending = true;
    update();
    Response response = await messageServiceInterface.sendMessage(conversationController.value.text,
        channelId, tripId ,_selectedImageList, objFile);
    if(response.statusCode == 200){
      isSending = false;
      getConversation(channelId, 1);
      conversationController.text='';
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile=null;
      objFile =null;
      _file=null;
    }
    else if(response.statusCode == 400){
      isSending = false;
      _markFailed(pending);
      String message = response.body['errors'][0]['message'];
      if(message.contains("png  jpg  jpeg  csv  txt  xlx  xls  pdf")){
        message = "the_files_types_must_be";
      }
      if(message.contains("failed to upload")){
        message = "failed_to_upload";
      }
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile=null;
      objFile =null;
      _file=null;
      showCustomSnackBar(message.tr);
    }
    else{
      isSending = false;
      _markFailed(pending);
      _pickedImageFiles = [];
      _selectedImageList = [];
      _otherFile=null;
      objFile =null;
      _file=null;
      ApiChecker.checkApi(response);
    }
    isLoading = false;
    update();
  }

  /// Kept for existing callers: the trip chat is now kept live by
  /// [ChatInboxController], which also survives reconnects.
  void subscribeMessageChannel(String tripId){
    Get.find<ChatInboxController>().watchTrip(tripId);
  }

  /// A message that arrived over the websocket while this chat is open.
  void insertIncoming(Message message) {
    final List<Message>? list = messageModel?.data;
    if (list == null) return;
    if (message.id != null && list.any((m) => m.id == message.id)) return;
    list.insert(0, message);
    messageModel!.totalSize = (messageModel!.totalSize ?? 0) + 1;
    update();
  }

  /// The other party read the chat: every message I sent is now "seen".
  void markMineRead() {
    final List<Message>? list = messageModel?.data;
    final String? me = Get.find<ProfileController>().profileModel?.data?.id;
    if (list == null || me == null) return;
    for (final Message m in list) {
      if ((m.user?.id ?? m.userId) == me && !m.isPending) m.isRead = true;
    }
    update();
  }

  void _markFailed(Message? pending) {
    if (pending == null) return;
    pending
      ..isPending = false
      ..isFailed = true;
  }

  /// Sends a failed text message again.
  Future<void> retryMessage(Message failed, String channelId, String tripId) async {
    messageModel?.data?.remove(failed);
    conversationController.text = failed.message ?? '';
    // sendMessage reads the text before its first await, so the box can be
    // cleared straight away.
    final Future<void> sending = sendMessage(channelId, tripId);
    conversationController.clear();
    update();
    await sending;
  }

  /// Sends a quick reply chip as a message.
  Future<void> sendQuickReply(String text, String channelId, String tripId) async {
    if (isSending) return;
    conversationController.text = text;
    final Future<void> sending = sendMessage(channelId, tripId);
    conversationController.clear();
    update();
    await sending;
  }

  bool _channelRideStatus = true;
  bool get channelRideStatus => _channelRideStatus;
  void findChannelRideStatus(String channelId) async{
    Response response = await messageServiceInterface.findChannelRideStatus(channelId);
    if(response.body['data'] == "cancelled" || response.body['data'] == 'completed'){
      _channelRideStatus = false;
    }else{
      _channelRideStatus = true;
    }
    update();
  }

}
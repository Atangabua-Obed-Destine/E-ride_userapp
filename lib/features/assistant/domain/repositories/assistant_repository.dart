import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/repositories/assistant_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class AssistantRepository implements AssistantRepositoryInterface {
  final ApiClient apiClient;
  AssistantRepository({required this.apiClient});

  @override
  Future getHelp() async => await apiClient.getData(AppConstants.assistantHelp);

  @override
  Future ask(Map<String, dynamic> body) async => await apiClient.postData(AppConstants.assistantAsk, body);

  @override
  Future feedback(String questionId, bool helped) async =>
      await apiClient.postData('${AppConstants.assistantBase}/$questionId/feedback', {'helped': helped});

  /// A voice note recorded while booking: kept for the driver, and read to fill the booking.
  @override
  Future voiceTrip(String path, int seconds, String kind, List<String> categories) async =>
      await apiClient.postMultipartData(
        AppConstants.assistantVoiceTrip,
        {
          'seconds': '$seconds',
          'kind': kind,
          for (int i = 0; i < categories.length; i++) 'categories[$i]': categories[i],
        },
        MultipartBody('', null),
        [MultipartBody('audio', XFile(path))],
      );

  @override
  Future add(value) => throw UnimplementedError();

  @override
  Future delete(String id) => throw UnimplementedError();

  @override
  Future get(String id) => throw UnimplementedError();

  @override
  Future getList({int? offset = 1}) => throw UnimplementedError();

  @override
  Future update(value, {int? id}) => throw UnimplementedError();
}

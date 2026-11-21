import 'package:ride_sharing_user_app/interface/repository_interface.dart';

abstract class AssistantRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getHelp();
  Future<dynamic> ask(Map<String, dynamic> body);
  Future<dynamic> feedback(String questionId, bool helped);
  Future<dynamic> voiceTrip(String path, int seconds, String kind, List<String> categories);
}

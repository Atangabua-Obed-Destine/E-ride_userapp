import 'package:ride_sharing_user_app/features/assistant/domain/repositories/assistant_repository_interface.dart';
import 'package:ride_sharing_user_app/features/assistant/domain/services/assistant_service_interface.dart';

class AssistantService implements AssistantServiceInterface {
  final AssistantRepositoryInterface assistantRepositoryInterface;
  AssistantService({required this.assistantRepositoryInterface});

  @override
  Future getHelp() => assistantRepositoryInterface.getHelp();

  @override
  Future ask(Map<String, dynamic> body) => assistantRepositoryInterface.ask(body);

  @override
  Future feedback(String questionId, bool helped) => assistantRepositoryInterface.feedback(questionId, helped);

  @override
  Future voiceTrip(String path, int seconds, String kind, List<String> categories) =>
      assistantRepositoryInterface.voiceTrip(path, seconds, kind, categories);
}

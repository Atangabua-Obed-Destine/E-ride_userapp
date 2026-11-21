abstract class AssistantServiceInterface {
  Future<dynamic> getHelp();
  Future<dynamic> ask(Map<String, dynamic> body);
  Future<dynamic> feedback(String questionId, bool helped);
  Future<dynamic> voiceTrip(String path, int seconds, String kind, List<String> categories);
}

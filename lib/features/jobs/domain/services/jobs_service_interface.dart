import 'package:image_picker/image_picker.dart';

/// E-Ride Jobs: what the controllers ask for (passes through to the repository).
abstract class JobsServiceInterface {
  Future<dynamic> getMeta();
  Future<dynamic> getFeed(Map<String, dynamic> query);
  Future<dynamic> getJob(String code);
  Future<dynamic> toggleSave(String code);
  Future<dynamic> report(String code, String reason, String? note);
  Future<dynamic> getCard();
  Future<dynamic> saveCard(Map<String, String> fields, XFile? cv, XFile? voice);
  Future<dynamic> apply(String code, Map<String, dynamic> body);
  Future<dynamic> getApplications();
  Future<dynamic> getApplication(String id);
  Future<dynamic> withdraw(String id);
  Future<dynamic> answerHire(String id, bool yes);
  Future<dynamic> getAlert();
  Future<dynamic> saveAlert(Map<String, dynamic> body);
  Future<dynamic> getEmployer();
  Future<dynamic> saveEmployer(Map<String, String> fields, XFile? logo, XFile? doc);
  Future<dynamic> getMyJobs();
  Future<dynamic> createJob(Map<String, dynamic> body);
  Future<dynamic> updateJob(String code, Map<String, dynamic> body);
  Future<dynamic> closeJob(String code);
  Future<dynamic> getApplicants(String code, String tab);
  Future<dynamic> getApplicant(String id);
  Future<dynamic> applicantAction(String id, String action, Map<String, dynamic> body);
}

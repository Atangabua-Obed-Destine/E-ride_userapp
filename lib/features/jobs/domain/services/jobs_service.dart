import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/repositories/jobs_repository_interface.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/services/jobs_service_interface.dart';

class JobsService implements JobsServiceInterface {
  final JobsRepositoryInterface jobsRepositoryInterface;
  JobsService({required this.jobsRepositoryInterface});

  @override
  Future<dynamic> getMeta() => jobsRepositoryInterface.getMeta();

  @override
  Future<dynamic> getFeed(Map<String, dynamic> query) => jobsRepositoryInterface.getFeed(query);

  @override
  Future<dynamic> getJob(String code) => jobsRepositoryInterface.getJob(code);

  @override
  Future<dynamic> toggleSave(String code) => jobsRepositoryInterface.toggleSave(code);

  @override
  Future<dynamic> report(String code, String reason, String? note) => jobsRepositoryInterface.report(code, reason, note);

  @override
  Future<dynamic> getCard() => jobsRepositoryInterface.getCard();

  @override
  Future<dynamic> saveCard(Map<String, String> fields, XFile? cv, XFile? voice) => jobsRepositoryInterface.saveCard(fields, cv, voice);

  @override
  Future<dynamic> apply(String code, Map<String, dynamic> body) => jobsRepositoryInterface.apply(code, body);

  @override
  Future<dynamic> getApplications() => jobsRepositoryInterface.getApplications();

  @override
  Future<dynamic> getApplication(String id) => jobsRepositoryInterface.getApplication(id);

  @override
  Future<dynamic> withdraw(String id) => jobsRepositoryInterface.withdraw(id);

  @override
  Future<dynamic> answerHire(String id, bool yes) => jobsRepositoryInterface.answerHire(id, yes);

  @override
  Future<dynamic> getAlert() => jobsRepositoryInterface.getAlert();

  @override
  Future<dynamic> saveAlert(Map<String, dynamic> body) => jobsRepositoryInterface.saveAlert(body);

  @override
  Future<dynamic> getEmployer() => jobsRepositoryInterface.getEmployer();

  @override
  Future<dynamic> saveEmployer(Map<String, String> fields, XFile? logo, XFile? doc) => jobsRepositoryInterface.saveEmployer(fields, logo, doc);

  @override
  Future<dynamic> getMyJobs() => jobsRepositoryInterface.getMyJobs();

  @override
  Future<dynamic> createJob(Map<String, dynamic> body) => jobsRepositoryInterface.createJob(body);

  @override
  Future<dynamic> updateJob(String code, Map<String, dynamic> body) => jobsRepositoryInterface.updateJob(code, body);

  @override
  Future<dynamic> closeJob(String code) => jobsRepositoryInterface.closeJob(code);

  @override
  Future<dynamic> getApplicants(String code, String tab) => jobsRepositoryInterface.getApplicants(code, tab);

  @override
  Future<dynamic> getApplicant(String id) => jobsRepositoryInterface.getApplicant(id);

  @override
  Future<dynamic> applicantAction(String id, String action, Map<String, dynamic> body) => jobsRepositoryInterface.applicantAction(id, action, body);
}

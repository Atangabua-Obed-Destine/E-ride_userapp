import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/repositories/jobs_repository_interface.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';

class JobsRepository implements JobsRepositoryInterface {
  final ApiClient apiClient;
  JobsRepository({required this.apiClient});

  static const String _j = AppConstants.jobs;

  @override
  Future getMeta() => apiClient.getData('$_j/meta');

  @override
  Future getFeed(Map<String, dynamic> query) => apiClient.getData('$_j/feed', query: query);

  @override
  Future getJob(String code) => apiClient.getData('$_j/jobs/$code');

  @override
  Future toggleSave(String code) => apiClient.postData('$_j/jobs/$code/save', {});

  @override
  Future report(String code, String reason, String? note) =>
      apiClient.postData('$_j/jobs/$code/report', {'reason': reason, if (note != null && note.isNotEmpty) 'note': note});

  @override
  Future getCard() => apiClient.getData('$_j/card');

  @override
  Future saveCard(Map<String, String> fields, XFile? cv, XFile? voice) =>
      // Both in the list: the ApiClient names its first file "<time>.png", which would rename a PDF CV.
      apiClient.postMultipartData('$_j/card', fields, MultipartBody('', null), [MultipartBody('cv', cv), MultipartBody('voice', voice)]);

  @override
  Future apply(String code, Map<String, dynamic> body) => apiClient.postData('$_j/jobs/$code/apply', body);

  @override
  Future getApplications() => apiClient.getData('$_j/applications');

  @override
  Future getApplication(String id) => apiClient.getData('$_j/applications/$id');

  @override
  Future withdraw(String id) => apiClient.postData('$_j/applications/$id/withdraw', {});

  @override
  Future answerHire(String id, bool yes) => apiClient.postData('$_j/applications/$id/hire-answer', {'yes': yes ? 1 : 0});

  @override
  Future getAlert() => apiClient.getData('$_j/alert');

  @override
  Future saveAlert(Map<String, dynamic> body) => apiClient.postData('$_j/alert', body);

  @override
  Future getEmployer() => apiClient.getData('$_j/employer');

  @override
  Future saveEmployer(Map<String, String> fields, XFile? logo, XFile? doc) =>
      apiClient.postMultipartData('$_j/employer', fields, MultipartBody('logo', logo), [MultipartBody('doc', doc)]);

  @override
  Future getMyJobs() => apiClient.getData('$_j/employer/jobs');

  @override
  Future createJob(Map<String, dynamic> body) => apiClient.postData('$_j/employer/jobs', body);

  @override
  Future updateJob(String code, Map<String, dynamic> body) => apiClient.postData('$_j/employer/jobs/$code/update', body);

  @override
  Future closeJob(String code) => apiClient.postData('$_j/employer/jobs/$code/close', {});

  @override
  Future getApplicants(String code, String tab) => apiClient.getData('$_j/employer/jobs/$code/applicants', query: {'tab': tab});

  @override
  Future getApplicant(String id) => apiClient.getData('$_j/employer/applications/$id');

  /// shortlist, not-selected, next-step, hire
  @override
  Future applicantAction(String id, String action, Map<String, dynamic> body) => apiClient.postData('$_j/employer/applications/$id/$action', body);
}

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/services/jobs_service_interface.dart';

/// E-Ride Jobs for employers: the employer check, posting and closing jobs, applicants,
/// and the answers (shortlist, not this time, the next step).
class JobsEmployerController extends GetxController implements GetxService {
  final JobsServiceInterface jobsServiceInterface;
  JobsEmployerController({required this.jobsServiceInterface});

  JobsServiceInterface get _service => jobsServiceInterface;

  bool saving = false;

  // ---------------------------------------------------------------- employer

  JobEmployer? employer;
  bool employerLoaded = false;

  Future<JobEmployer?> loadEmployer() async {
    Response response = await _service.getEmployer();
    if (response.statusCode == 200) {
      final e = response.body['data']['employer'];
      employer = e is Map ? JobEmployer.fromJson(Map<String, dynamic>.from(e)) : null;
      employerLoaded = true;
    } else {
      ApiChecker.checkApi(response);
    }
    update();
    return employer;
  }

  Future<bool> saveEmployer(Map<String, String> fields, {XFile? logo, XFile? doc}) async {
    if (saving) return false;
    saving = true;
    update();
    Response response = await _service.saveEmployer(fields, logo, doc);
    saving = false;
    if (response.statusCode == 200) {
      employer = JobEmployer.fromJson(Map<String, dynamic>.from(response.body['data']['employer']));
      employerLoaded = true;
      update();
      _refreshMeta();
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- my jobs

  final List<JobPost> myJobs = [];
  bool jobsLoading = false;
  bool jobsLoaded = false;

  JobPost? myJob(String code) => myJobs.firstWhereOrNull((j) => j.code == code);

  Future<void> loadMyJobs() async {
    jobsLoading = true;
    update();
    Response response = await _service.getMyJobs();
    jobsLoading = false;
    if (response.statusCode == 200) {
      myJobs
        ..clear()
        ..addAll([for (final j in response.body['data']['jobs'] as List) JobPost.fromJson(Map<String, dynamic>.from(j))]);
      jobsLoaded = true;
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<JobPost?> saveJob(Map<String, dynamic> body, {String? code}) async {
    if (saving) return null;
    saving = true;
    update();
    Response response = code == null ? await _service.createJob(body) : await _service.updateJob(code, body);
    saving = false;
    update();
    if (response.statusCode == 200) {
      final job = JobPost.fromJson(Map<String, dynamic>.from(response.body['data']));
      loadMyJobs();
      _refreshMeta();
      return job;
    }
    ApiChecker.checkApi(response);
    return null;
  }

  Future<bool> closeJob(String code) async {
    Response response = await _service.closeJob(code);
    if (response.statusCode == 200) {
      await loadMyJobs();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- applicants

  /// "CODE:tab" -> applicants
  final Map<String, List<JobApplicant>> _lists = {};
  final Map<String, Map<String, int>> _counts = {};
  final Set<String> _loading = {};

  List<JobApplicant> applicants(String code, String tab) => _lists['$code:$tab'] ?? const [];
  int count(String code, String tab) => _counts[code]?[tab] ?? 0;
  bool isLoading(String code, String tab) => _loading.contains('$code:$tab');

  Future<void> loadApplicants(String code, String tab) async {
    final key = '$code:$tab';
    _loading.add(key);
    update();
    Response response = await _service.getApplicants(code, tab);
    _loading.remove(key);
    if (response.statusCode == 200) {
      final data = response.body['data'];
      _lists[key] = [for (final a in data['applicants'] as List) JobApplicant.fromJson(Map<String, dynamic>.from(a))];
      final c = data['counts'];
      if (c is Map) _counts[code] = {for (final e in c.entries) '${e.key}': int.tryParse('${e.value}') ?? 0};
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  final Map<String, JobApplicant> _applicants = {};
  JobApplicant? applicant(String id) => _applicants[id];

  Future<JobApplicant?> loadApplicant(String id) async {
    Response response = await _service.getApplicant(id);
    if (response.statusCode == 200) {
      _applicants[id] = JobApplicant.fromJson(Map<String, dynamic>.from(response.body['data']));
      update();
      _refreshMeta();
      return _applicants[id];
    }
    ApiChecker.checkApi(response);
    update();
    return null;
  }

  /// shortlist, not-selected, next-step
  Future<JobApplicant?> act(String id, String action, [Map<String, dynamic> body = const {}]) async {
    if (saving) return null;
    saving = true;
    update();
    Response response = await _service.applicantAction(id, action, body);
    saving = false;
    if (response.statusCode == 200) {
      final a = JobApplicant.fromJson(Map<String, dynamic>.from(response.body['data']));
      _applicants[id] = a;
      update();
      if (a.jobCode != null) {
        for (final tab in const ['new', 'shortlist', 'other']) {
          if (_lists.containsKey('${a.jobCode}:$tab')) loadApplicants(a.jobCode!, tab);
        }
      }
      return a;
    }
    update();
    ApiChecker.checkApi(response);
    return null;
  }

  void _refreshMeta() {
    if (Get.isRegistered<JobsController>()) Get.find<JobsController>().loadMeta(force: true);
  }
}

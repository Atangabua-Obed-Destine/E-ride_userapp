import 'dart:convert';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/services/jobs_service_interface.dart';

/// E-Ride Jobs for job seekers: the feed, one job, saves and reports, the Work Card,
/// applying, my applications and job alerts.
class JobsController extends GetxController implements GetxService {
  final JobsServiceInterface jobsServiceInterface;
  JobsController({required this.jobsServiceInterface});

  JobsServiceInterface get _service => jobsServiceInterface;

  // ---------------------------------------------------------------- meta

  JobsMeta? meta;
  Future<JobsMeta?>? _metaCall;

  Future<JobsMeta?> loadMeta({bool force = false}) async {
    if (meta != null && !force) return meta;
    while (_metaCall != null) {
      await _metaCall;
      if (!force) return meta;
    }
    _metaCall = () async {
      Response response = await _service.getMeta();
      if (response.statusCode == 200) {
        meta = JobsMeta.fromJson(Map<String, dynamic>.from(response.body['data']));
      }
      update();
      return meta;
    }();
    try {
      return await _metaCall;
    } finally {
      _metaCall = null;
    }
  }

  // ---------------------------------------------------------------- feed

  final List<JobPost> feed = [];
  bool feedLoading = false;
  bool hasMore = false;
  int _page = 1;
  int _feedCall = 0;
  String query = '';
  String? category;
  String? type;
  bool savedOnly = false;

  bool get hasFilters => query.isNotEmpty || category != null || type != null || savedOnly;

  Future<void> loadFeed() async {
    final call = ++_feedCall;
    _page = 1;
    feedLoading = true;
    update();
    Response response = await _service.getFeed(_query(1));
    if (call != _feedCall) return;
    feedLoading = false;
    if (response.statusCode == 200) {
      feed
        ..clear()
        ..addAll(_jobs(response.body['data']));
      hasMore = response.body['data']['has_more'] == true;
    } else {
      feed.clear();
      hasMore = false;
      if (response.statusCode != 403) ApiChecker.checkApi(response);
    }
    update();
  }

  Future<void> loadMore() async {
    if (feedLoading || !hasMore) return;
    final call = _feedCall;
    feedLoading = true;
    update();
    Response response = await _service.getFeed(_query(_page + 1));
    feedLoading = false;
    if (call == _feedCall && response.statusCode == 200) {
      _page++;
      feed.addAll(_jobs(response.body['data']));
      hasMore = response.body['data']['has_more'] == true;
    }
    update();
  }

  void setQuery(String q) {
    query = q.trim();
    loadFeed();
  }

  void setCategory(String? value) {
    category = category == value ? null : value;
    loadFeed();
  }

  void setType(String? value) {
    type = type == value ? null : value;
    loadFeed();
  }

  void setSavedOnly(bool on) {
    savedOnly = on;
    loadFeed();
  }

  void clearFilters() {
    query = '';
    category = null;
    type = null;
    savedOnly = false;
    loadFeed();
  }

  Map<String, dynamic> _query(int page) => {
        'page': page,
        if (query.isNotEmpty) 'q': query,
        if (category != null) 'category': category,
        if (type != null) 'type': type,
        if (savedOnly) 'saved': 1,
      };

  List<JobPost> _jobs(dynamic data) => [for (final j in data['jobs'] as List) JobPost.fromJson(Map<String, dynamic>.from(j))];

  // ---------------------------------------------------------------- one job

  final Map<String, JobPost> _jobsByCode = {};
  final Set<String> _gone = {};
  bool jobLoading = false;

  JobPost? job(String code) => _jobsByCode[code];
  bool isGone(String code) => _gone.contains(code);

  Future<JobPost?> loadJob(String code) async {
    jobLoading = true;
    update();
    Response response = await _service.getJob(code);
    jobLoading = false;
    if (response.statusCode == 200) {
      _jobsByCode[code] = JobPost.fromJson(Map<String, dynamic>.from(response.body['data']));
      _gone.remove(code);
    } else if (response.statusCode == 404) {
      _gone.add(code);
    } else {
      ApiChecker.checkApi(response);
    }
    update();
    return _jobsByCode[code];
  }

  Future<void> toggleSave(String code) async {
    final current = _jobsByCode[code];
    if (current != null) _jobsByCode[code] = current.copyWith(saved: !current.saved);
    update();
    Response response = await _service.toggleSave(code);
    if (response.statusCode == 200) {
      final saved = response.body['data']['saved'] == true;
      if (current != null) _jobsByCode[code] = current.copyWith(saved: saved);
      if (savedOnly && !saved) feed.removeWhere((j) => j.code == code);
    } else {
      if (current != null) _jobsByCode[code] = current;
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<bool> report(String code, String reason, String? note) async {
    Response response = await _service.report(code, reason, note);
    if (response.statusCode == 200) return true;
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- Work Card

  WorkCard? card;
  bool cardLoaded = false;
  String suggestedName = '';
  bool saving = false;

  Future<WorkCard?> loadCard() async {
    Response response = await _service.getCard();
    if (response.statusCode == 200) {
      final data = response.body['data'];
      card = data['card'] is Map ? WorkCard.fromJson(Map<String, dynamic>.from(data['card'])) : null;
      suggestedName = '${data['suggested_name'] ?? ''}';
      cardLoaded = true;
    } else {
      ApiChecker.checkApi(response);
    }
    update();
    return card;
  }

  Future<bool> saveCard({
    required String name,
    String? area,
    String? languages,
    String? headline,
    String? education,
    required List<String> skills,
    required List<WorkExperience> experience,
    required List<String> lookingFor,
    required List<WorkLink> links,
    XFile? cv,
    bool removeCv = false,
    XFile? voice,
    int? voiceSeconds,
    bool removeVoice = false,
  }) async {
    if (saving) return false;
    saving = true;
    update();
    Response response = await _service.saveCard({
      'name': name,
      'area_label': area ?? '',
      'languages': languages ?? '',
      'headline': headline ?? '',
      'education': education ?? '',
      'skills': jsonEncode(skills),
      'experience': jsonEncode([for (final e in experience) e.toJson()]),
      'looking_for': jsonEncode(lookingFor),
      'links': jsonEncode([for (final l in links) l.toJson()]),
      if (removeCv) 'remove_cv': '1',
      if (voice != null && voiceSeconds != null) 'voice_seconds': '$voiceSeconds',
      if (removeVoice && voice == null) 'remove_voice': '1',
    }, cv, voice);
    saving = false;
    if (response.statusCode == 200) {
      card = WorkCard.fromJson(Map<String, dynamic>.from(response.body['data']['card']));
      cardLoaded = true;
      update();
      loadMeta(force: true);
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- applying

  Future<JobApplication?> apply(String code, List<bool> answers, String? message, bool sharePhone) async {
    if (saving) return null;
    saving = true;
    update();
    Response response = await _service.apply(code, {
      'answers': answers,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      'share_phone': sharePhone ? 1 : 0,
    });
    saving = false;
    update();
    if (response.statusCode == 200) {
      final application = JobApplication.fromJson(Map<String, dynamic>.from(response.body['data']));
      _applications[application.id] = application;
      loadJob(code);
      loadApplications();
      loadMeta(force: true);
      final i = feed.indexWhere((j) => j.code == code);
      if (i >= 0) loadFeed();
      return application;
    }
    ApiChecker.checkApi(response);
    return null;
  }

  final List<JobApplication> applications = [];
  final Map<String, JobApplication> _applications = {};
  bool applicationsLoading = false;
  bool applicationsLoaded = false;

  JobApplication? application(String id) => _applications[id];

  Future<void> loadApplications() async {
    applicationsLoading = true;
    update();
    Response response = await _service.getApplications();
    applicationsLoading = false;
    if (response.statusCode == 200) {
      applications
        ..clear()
        ..addAll([for (final a in response.body['data']['applications'] as List) JobApplication.fromJson(Map<String, dynamic>.from(a))]);
      for (final a in applications) {
        _applications[a.id] = a;
      }
      applicationsLoaded = true;
    } else {
      ApiChecker.checkApi(response);
    }
    update();
  }

  Future<JobApplication?> loadApplication(String id) async {
    Response response = await _service.getApplication(id);
    if (response.statusCode == 200) {
      final a = JobApplication.fromJson(Map<String, dynamic>.from(response.body['data']));
      _applications[id] = a;
      final i = applications.indexWhere((x) => x.id == id);
      if (i >= 0) applications[i] = a;
      update();
      loadMeta(force: true);
      return a;
    }
    ApiChecker.checkApi(response);
    update();
    return null;
  }

  /// yes: I got the job (counts for the employer); no: I did not.
  Future<bool> answerHire(String id, bool yes) async {
    if (saving) return false;
    saving = true;
    update();
    Response response = await _service.answerHire(id, yes);
    saving = false;
    if (response.statusCode == 200) {
      final a = JobApplication.fromJson(Map<String, dynamic>.from(response.body['data']));
      _applications[id] = a;
      final i = applications.indexWhere((x) => x.id == id);
      if (i >= 0) applications[i] = a;
      update();
      return true;
    }
    update();
    ApiChecker.checkApi(response);
    return false;
  }

  Future<bool> withdraw(String id) async {
    Response response = await _service.withdraw(id);
    if (response.statusCode == 200) {
      final a = JobApplication.fromJson(Map<String, dynamic>.from(response.body['data']));
      _applications[id] = a;
      loadApplications();
      if (a.job != null) loadJob(a.job!.code);
      update();
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }

  // ---------------------------------------------------------------- alerts

  JobAlertPrefs? alert;

  Future<JobAlertPrefs?> loadAlert() async {
    Response response = await _service.getAlert();
    if (response.statusCode == 200) {
      alert = JobAlertPrefs.fromJson(Map<String, dynamic>.from(response.body['data']));
    }
    update();
    return alert;
  }

  Future<bool> saveAlert(bool enabled, List<String> categories, List<String> types) async {
    saving = true;
    update();
    Response response = await _service.saveAlert({'enabled': enabled ? 1 : 0, 'categories': categories, 'types': types});
    saving = false;
    update();
    if (response.statusCode == 200) {
      alert = JobAlertPrefs(enabled: enabled, categories: categories, types: types, perDay: alert?.perDay ?? 2);
      loadMeta(force: true);
      return true;
    }
    ApiChecker.checkApi(response);
    return false;
  }
}

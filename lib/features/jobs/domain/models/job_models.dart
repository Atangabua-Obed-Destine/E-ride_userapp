// E-Ride Jobs: verified jobs, the Work Card, applications, and the employer's side.
// Applying is free; E-Ride stops at the employer's next step (no interviews or hiring in the app).

double? _num(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
String? _text(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<String> _strings(dynamic v) => v is List ? [for (final x in v) '$x'] : const [];

class JobsMeta {
  final bool enabled;
  final List<String> categories;
  final List<String> types;
  final List<String> periods;
  final List<String> reportReasons;
  final List<String> docTypes;
  final List<String> linkTypes;
  final int maxQuestions;
  final int reviewHours;
  final int staleDays;
  final int cardPercent;
  final bool cardCanApply;
  final int nextStepsUnread;
  final int applicationsOpen;
  final int hiresToConfirm;
  final JobEmployer? employer;
  final int newApplicants;
  final bool alertOn;

  /// What needs me in Jobs: next steps to read, a hire to confirm, new applicants to look at.
  int get attention => nextStepsUnread + hiresToConfirm + newApplicants;

  const JobsMeta({
    this.enabled = false,
    this.categories = const ['sales', 'shop_restaurant', 'cleaning', 'driving', 'office', 'teaching', 'health', 'building', 'security', 'beauty', 'tech', 'other'],
    this.types = const ['full_time', 'part_time', 'day_job', 'internship'],
    this.periods = const ['month', 'week', 'day', 'hour', 'job'],
    this.reportReasons = const ['fee', 'fake', 'pay', 'rude', 'other'],
    this.docTypes = const ['licence', 'niu', 'id'],
    this.linkTypes = const ['linkedin', 'github', 'portfolio', 'website', 'other'],
    this.maxQuestions = 3,
    this.reviewHours = 2,
    this.staleDays = 21,
    this.cardPercent = 0,
    this.cardCanApply = false,
    this.nextStepsUnread = 0,
    this.applicationsOpen = 0,
    this.hiresToConfirm = 0,
    this.employer,
    this.newApplicants = 0,
    this.alertOn = false,
  });

  factory JobsMeta.fromJson(Map<String, dynamic> j) => JobsMeta(
        enabled: j['enabled'] == true,
        categories: j['categories'] is List ? _strings(j['categories']) : const JobsMeta().categories,
        types: j['types'] is List ? _strings(j['types']) : const JobsMeta().types,
        periods: j['periods'] is List ? _strings(j['periods']) : const JobsMeta().periods,
        reportReasons: j['report_reasons'] is List ? _strings(j['report_reasons']) : const JobsMeta().reportReasons,
        docTypes: j['doc_types'] is List ? _strings(j['doc_types']) : const JobsMeta().docTypes,
        linkTypes: j['link_types'] is List ? _strings(j['link_types']) : const JobsMeta().linkTypes,
        maxQuestions: _int(j['max_questions']) == 0 ? 3 : _int(j['max_questions']),
        reviewHours: _int(j['review_hours']) == 0 ? 2 : _int(j['review_hours']),
        staleDays: _int(j['stale_days']) == 0 ? 21 : _int(j['stale_days']),
        cardPercent: _int(j['card_percent']),
        cardCanApply: j['card_can_apply'] == true,
        nextStepsUnread: _int(j['next_steps_unread']),
        applicationsOpen: _int(j['applications_open']),
        hiresToConfirm: _int(j['hires_to_confirm']),
        employer: j['employer'] is Map ? JobEmployer.fromJson(Map<String, dynamic>.from(j['employer'])) : null,
        newApplicants: _int(j['new_applicants']),
        alertOn: j['alert_on'] == true,
      );
}

class JobEmployer {
  static const String pending = 'pending';
  static const String verified = 'verified';
  static const String rejected = 'rejected';
  static const String frozen = 'frozen';

  final String id;
  final String name;
  final String kind;
  final String? logo;
  final bool isVerified;
  final String? area;
  final String? about;
  /// People who confirmed they were hired through E-Ride.
  final int hires;
  // Only on my own employer profile.
  final String? status;
  final String? reviewNote;
  final String? docType;
  final bool hasDoc;
  final double? lat;
  final double? lng;
  final String? address;

  const JobEmployer({required this.id, required this.name, this.kind = 'business', this.logo, this.isVerified = false, this.area, this.about,
      this.hires = 0, this.status, this.reviewNote, this.docType, this.hasDoc = false, this.lat, this.lng, this.address});

  bool get isPrivate => kind == 'private';

  factory JobEmployer.fromJson(Map<String, dynamic> j) => JobEmployer(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        kind: '${j['kind'] ?? 'business'}',
        logo: _text(j['logo']),
        isVerified: j['verified'] == true,
        area: _text(j['area']),
        about: _text(j['about']),
        hires: _int(j['hires']),
        status: _text(j['status']),
        reviewNote: _text(j['review_note']),
        docType: _text(j['doc_type']),
        hasDoc: j['has_doc'] == true,
        lat: _num(j['lat']),
        lng: _num(j['lng']),
        address: _text(j['address']),
      );
}

class JobPost {
  static const String review = 'review';
  static const String live = 'live';
  static const String sentBack = 'sent_back';
  static const String rejected = 'rejected';
  static const String closed = 'closed';
  static const String hidden = 'hidden';

  final String code;
  final String title;
  final String category;
  final String type;
  final double payMin;
  final double? payMax;
  final String payPeriod;
  final String? schedule;
  final int places;
  final String? area;
  final String status;
  final bool isLive;
  final DateTime? liveAt;
  final DateTime? closesAt;
  final int applications;
  final JobEmployer? employer;
  final bool mine;
  final String link;
  /// My application's status on this job (feed rows), or null.
  final String? applied;
  // Full job
  final String? description;
  final String? requirements;
  final List<String> skills;
  final List<String> questions;
  /// Links an applicant must have on their Work Card (linkedin, github...).
  final List<String> requiredLinks;
  final double? lat;
  final double? lng;
  final String? address;
  final bool saved;
  final String? myApplicationId;
  final String? myApplicationStatus;
  // Mine (employer)
  final int views;
  final int alerted;
  final String? reviewNote;
  final int newApplications;
  final int hired;

  const JobPost({
    required this.code, required this.title, required this.category, required this.type, required this.payMin, this.payMax,
    this.payPeriod = 'month', this.schedule, this.places = 1, this.area, this.status = live, this.isLive = false, this.liveAt, this.closesAt,
    this.applications = 0, this.employer, this.mine = false, this.link = '', this.applied, this.description, this.requirements,
    this.skills = const [], this.questions = const [], this.requiredLinks = const [], this.lat, this.lng, this.address, this.saved = false,
    this.myApplicationId, this.myApplicationStatus, this.views = 0, this.alerted = 0, this.reviewNote, this.newApplications = 0, this.hired = 0,
  });

  JobPost copyWith({bool? saved}) => JobPost(
        code: code, title: title, category: category, type: type, payMin: payMin, payMax: payMax, payPeriod: payPeriod, schedule: schedule,
        places: places, area: area, status: status, isLive: isLive, liveAt: liveAt, closesAt: closesAt, applications: applications,
        employer: employer, mine: mine, link: link, applied: applied, description: description, requirements: requirements, skills: skills,
        questions: questions, requiredLinks: requiredLinks, lat: lat, lng: lng, address: address, saved: saved ?? this.saved,
        myApplicationId: myApplicationId, myApplicationStatus: myApplicationStatus, views: views, alerted: alerted, reviewNote: reviewNote,
        newApplications: newApplications, hired: hired,
      );

  factory JobPost.fromJson(Map<String, dynamic> j) {
    final my = j['my_application'];
    return JobPost(
      code: '${j['code']}',
      title: '${j['title'] ?? ''}',
      category: '${j['category'] ?? 'other'}',
      type: '${j['type'] ?? 'full_time'}',
      payMin: _num(j['pay_min']) ?? 0,
      payMax: _num(j['pay_max']),
      payPeriod: '${j['pay_period'] ?? 'month'}',
      schedule: _text(j['schedule']),
      places: _int(j['places']) == 0 ? 1 : _int(j['places']),
      area: _text(j['area']),
      status: '${j['status'] ?? live}',
      isLive: j['live'] == true,
      liveAt: _date(j['live_at']),
      closesAt: _date(j['closes_at']),
      applications: _int(j['applications']),
      employer: j['employer'] is Map ? JobEmployer.fromJson(Map<String, dynamic>.from(j['employer'])) : null,
      mine: j['mine'] == true,
      link: '${j['link'] ?? ''}',
      applied: _text(j['applied']),
      description: _text(j['description']),
      requirements: _text(j['requirements']),
      skills: _strings(j['skills']),
      questions: _strings(j['questions']),
      requiredLinks: _strings(j['required_links']),
      lat: _num(j['lat']),
      lng: _num(j['lng']),
      address: _text(j['address']),
      saved: j['saved'] == true,
      myApplicationId: my is Map ? _text(my['id']) : null,
      myApplicationStatus: my is Map ? _text(my['status']) : null,
      views: _int(j['views']),
      alerted: _int(j['alerted']),
      reviewNote: _text(j['review_note']),
      newApplications: _int(j['new_applications']),
      hired: _int(j['hired']),
    );
  }
}

class WorkExperience {
  final String title;
  final String? place;
  final String? from;
  final String? to;
  const WorkExperience({required this.title, this.place, this.from, this.to});

  factory WorkExperience.fromJson(Map<String, dynamic> j) =>
      WorkExperience(title: '${j['title'] ?? ''}', place: _text(j['place']), from: _text(j['from']), to: _text(j['to']));

  Map<String, String> toJson() => {'title': title, 'place': place ?? '', 'from': from ?? '', 'to': to ?? ''};

  String get years => [if (from != null) from!, if (to != null) to!].join(' - ');
}

class WorkLink {
  final String type;
  final String url;
  const WorkLink({required this.type, required this.url});

  factory WorkLink.fromJson(Map<String, dynamic> j) => WorkLink(type: '${j['type'] ?? 'other'}', url: '${j['url'] ?? ''}');

  Map<String, String> toJson() => {'type': type, 'url': url};
}

class WorkCard {
  final String name;
  final String? area;
  final String? languages;
  final String? headline;
  final List<String> skills;
  final List<WorkExperience> experience;
  final String? education;
  final List<String> lookingFor;
  final String? cvUrl;
  final String? cvName;
  final bool hasCv;
  final String? voiceUrl;
  final int? voiceSeconds;
  final bool hasVoice;
  final List<WorkLink> links;
  final int percent;
  final bool canApply;

  const WorkCard({required this.name, this.area, this.languages, this.headline, this.skills = const [], this.experience = const [],
      this.education, this.lookingFor = const [], this.cvUrl, this.cvName, this.hasCv = false, this.voiceUrl, this.voiceSeconds,
      this.hasVoice = false, this.links = const [], this.percent = 0, this.canApply = false});

  bool hasLink(String type) => links.any((l) => l.type == type);

  factory WorkCard.fromJson(Map<String, dynamic> j) => WorkCard(
        name: '${j['name'] ?? ''}',
        area: _text(j['area']),
        languages: _text(j['languages']),
        headline: _text(j['headline']),
        skills: _strings(j['skills']),
        experience: j['experience'] is List
            ? [for (final e in j['experience'] as List) if (e is Map) WorkExperience.fromJson(Map<String, dynamic>.from(e))]
            : const [],
        education: _text(j['education']),
        lookingFor: _strings(j['looking_for']),
        cvUrl: _text(j['cv_url']),
        cvName: _text(j['cv_name']),
        hasCv: j['has_cv'] == true,
        voiceUrl: _text(j['voice_url']),
        voiceSeconds: j['voice_seconds'] == null ? null : _int(j['voice_seconds']),
        hasVoice: j['has_voice'] == true,
        links: j['links'] is List ? [for (final l in j['links'] as List) if (l is Map) WorkLink.fromJson(Map<String, dynamic>.from(l))] : const [],
        percent: _int(j['percent']),
        canApply: j['can_apply'] == true,
      );
}

/// My application, as the person who sent it sees it.
class JobApplication {
  static const String sent = 'sent';
  static const String seen = 'seen';
  static const String shortlisted = 'shortlisted';
  static const String nextStepStatus = 'next_step';
  static const String notSelected = 'not_selected';
  static const String withdrawn = 'withdrawn';
  static const String hired = 'hired';
  static const String closed = 'closed';

  final String id;
  final String status;
  final JobPost? job;
  final List<bool> answers;
  final List<String> questions;
  final String? message;
  final bool sharePhone;
  final String? employerNote;
  final String? nextStep;
  final DateTime? nextStepAt;
  final String? nextStepPlace;
  final DateTime? nextStepSentAt;
  final bool nextStepUnread;
  final double? nextStepLat;
  final double? nextStepLng;
  final DateTime? hiredAt;
  final bool hireConfirmed;
  final String? closedReason;
  final DateTime? sentAt;
  final DateTime? seenAt;
  final DateTime? shortlistedAt;
  final DateTime? updatedAt;

  const JobApplication({required this.id, required this.status, this.job, this.answers = const [], this.questions = const [], this.message,
      this.sharePhone = false, this.employerNote, this.nextStep, this.nextStepAt, this.nextStepPlace, this.nextStepSentAt,
      this.nextStepUnread = false, this.nextStepLat, this.nextStepLng, this.hiredAt, this.hireConfirmed = false, this.closedReason, this.sentAt,
      this.seenAt, this.shortlistedAt, this.updatedAt});

  bool get isOpen => [sent, seen, shortlisted, nextStepStatus, hired].contains(status);
  /// The employer says I got the job and waits for my answer.
  bool get hireToAnswer => status == hired && !hireConfirmed;

  factory JobApplication.fromJson(Map<String, dynamic> j) => JobApplication(
        id: '${j['id']}',
        status: '${j['status'] ?? sent}',
        job: j['job'] is Map ? JobPost.fromJson(Map<String, dynamic>.from(j['job'])) : null,
        answers: j['answers'] is List ? [for (final a in j['answers'] as List) a == true || a == 1 || a == '1'] : const [],
        questions: _strings(j['questions']),
        message: _text(j['message']),
        sharePhone: j['share_phone'] == true,
        employerNote: _text(j['employer_note']),
        nextStep: _text(j['next_step']),
        nextStepAt: _date(j['next_step_at']),
        nextStepPlace: _text(j['next_step_place']),
        nextStepSentAt: _date(j['next_step_sent_at']),
        nextStepUnread: j['next_step_unread'] == true,
        nextStepLat: _num(j['next_step_lat']),
        nextStepLng: _num(j['next_step_lng']),
        hiredAt: _date(j['hired_at']),
        hireConfirmed: j['hire_confirmed'] == true,
        closedReason: _text(j['closed_reason']),
        sentAt: _date(j['sent_at']),
        seenAt: _date(j['seen_at']),
        shortlistedAt: _date(j['shortlisted_at']),
        updatedAt: _date(j['updated_at']),
      );
}

class JobFit {
  final int yes;
  final int questions;
  final int skills;
  final int skillsOf;
  final int score;
  final int of;
  const JobFit({this.yes = 0, this.questions = 0, this.skills = 0, this.skillsOf = 0, this.score = 0, this.of = 0});

  factory JobFit.fromJson(Map<String, dynamic> j) => JobFit(
      yes: _int(j['yes']), questions: _int(j['questions']), skills: _int(j['skills']), skillsOf: _int(j['skills_of']), score: _int(j['score']), of: _int(j['of']));
}

/// One applicant, as the employer sees them.
class JobApplicant {
  final String id;
  final String status;
  final String name;
  final String? area;
  final String? headline;
  final List<String> skills;
  final List<bool> answers;
  final JobFit? fit;
  final bool hasCv;
  final bool hasVoice;
  final int? voiceSeconds;
  final int linksCount;
  final bool hasMessage;
  final bool? nextStepRead;
  final DateTime? hiredAt;
  final bool hireConfirmed;
  final DateTime? sentAt;
  // Full
  final WorkCard? card;
  final List<String> questions;
  final String? message;
  final String? phone;
  final String? employerNote;
  final String? nextStep;
  final DateTime? nextStepAt;
  final String? nextStepPlace;
  final DateTime? nextStepSentAt;
  final double? nextStepLat;
  final double? nextStepLng;
  final String? jobCode;
  final String? jobTitle;
  final int jobPlaces;
  final int jobHired;
  final String? jobStatus;
  final double? jobLat;
  final double? jobLng;
  final String? jobAddress;

  const JobApplicant({required this.id, required this.status, required this.name, this.area, this.headline, this.skills = const [],
      this.answers = const [], this.fit, this.hasCv = false, this.hasVoice = false, this.voiceSeconds, this.linksCount = 0, this.hasMessage = false,
      this.nextStepRead, this.hiredAt, this.hireConfirmed = false, this.sentAt, this.card, this.questions = const [], this.message, this.phone,
      this.employerNote, this.nextStep, this.nextStepAt, this.nextStepPlace, this.nextStepSentAt, this.nextStepLat, this.nextStepLng, this.jobCode,
      this.jobTitle, this.jobPlaces = 1, this.jobHired = 0, this.jobStatus, this.jobLat, this.jobLng, this.jobAddress});

  factory JobApplicant.fromJson(Map<String, dynamic> j) => JobApplicant(
        id: '${j['id']}',
        status: '${j['status'] ?? JobApplication.sent}',
        name: '${j['name'] ?? ''}',
        area: _text(j['area']),
        headline: _text(j['headline']),
        skills: _strings(j['skills']),
        answers: j['answers'] is List ? [for (final a in j['answers'] as List) a == true || a == 1 || a == '1'] : const [],
        fit: j['fit'] is Map ? JobFit.fromJson(Map<String, dynamic>.from(j['fit'])) : null,
        hasCv: j['has_cv'] == true,
        hasVoice: j['has_voice'] == true,
        voiceSeconds: j['voice_seconds'] == null ? null : _int(j['voice_seconds']),
        linksCount: _int(j['links']),
        hasMessage: j['has_message'] == true,
        nextStepRead: j['next_step_read'] is bool ? j['next_step_read'] as bool : null,
        hiredAt: _date(j['hired_at']),
        hireConfirmed: j['hire_confirmed'] == true,
        sentAt: _date(j['sent_at']),
        card: j['card'] is Map ? WorkCard.fromJson(Map<String, dynamic>.from(j['card'])) : null,
        questions: _strings(j['questions']),
        message: _text(j['message']),
        phone: _text(j['phone']),
        employerNote: _text(j['employer_note']),
        nextStep: _text(j['next_step']),
        nextStepAt: _date(j['next_step_at']),
        nextStepPlace: _text(j['next_step_place']),
        nextStepSentAt: _date(j['next_step_sent_at']),
        nextStepLat: _num(j['next_step_lat']),
        nextStepLng: _num(j['next_step_lng']),
        jobCode: j['job'] is Map ? _text(j['job']['code']) : null,
        jobTitle: j['job'] is Map ? _text(j['job']['title']) : null,
        jobPlaces: j['job'] is Map ? (_int(j['job']['places']) == 0 ? 1 : _int(j['job']['places'])) : 1,
        jobHired: j['job'] is Map ? _int(j['job']['hired']) : 0,
        jobStatus: j['job'] is Map ? _text(j['job']['status']) : null,
        jobLat: j['job'] is Map ? _num(j['job']['lat']) : null,
        jobLng: j['job'] is Map ? _num(j['job']['lng']) : null,
        jobAddress: j['job'] is Map ? _text(j['job']['address']) : null,
      );
}

class JobAlertPrefs {
  final bool enabled;
  final List<String> categories;
  final List<String> types;
  final int perDay;
  const JobAlertPrefs({this.enabled = false, this.categories = const [], this.types = const [], this.perDay = 2});

  factory JobAlertPrefs.fromJson(Map<String, dynamic> j) => JobAlertPrefs(
      enabled: j['enabled'] == true, categories: _strings(j['categories']), types: _strings(j['types']), perDay: _int(j['per_day']) == 0 ? 2 : _int(j['per_day']));
}

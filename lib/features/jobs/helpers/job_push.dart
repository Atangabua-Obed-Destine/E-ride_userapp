import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_employer_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/applicants_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/job_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/jobs_home_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_applications_screen.dart';
import 'package:ride_sharing_user_app/features/jobs/screens/my_jobs_screen.dart';

/// E-Ride Jobs pushes (actions job_*): keep open screens fresh, and the screen a tap opens.
class JobPush {
  JobPush._();

  static bool isJobPush(Map<String, dynamic> data) => '${data['action']}'.startsWith('job_');

  /// The app is open: refresh what the push changed. Always shows the notification.
  static bool onForeground(Map<String, dynamic> data) {
    final String action = '${data['action']}';
    final String? application = data['application_id']?.toString();
    final String? code = data['job_code']?.toString();
    if (Get.isRegistered<JobsController>()) {
      final jobs = Get.find<JobsController>();
      jobs.loadMeta(force: true);
      if (application != null && jobs.application(application) != null) jobs.loadApplication(application);
      if (jobs.applicationsLoaded) jobs.loadApplications();
    }
    if (Get.isRegistered<JobsEmployerController>()) {
      final employer = Get.find<JobsEmployerController>();
      if (employer.jobsLoaded) employer.loadMyJobs();
      if (employer.employerLoaded && action.startsWith('job_employer_')) employer.loadEmployer();
      if (code != null && action == 'job_application_new') {
        for (final tab in const ['new', 'shortlist', 'other']) {
          if (employer.applicants(code, tab).isNotEmpty || tab == 'new') employer.loadApplicants(code, tab);
        }
      }
    }
    return false;
  }

  static Widget screenFor(Map<String, dynamic> data) {
    final String action = '${data['action']}';
    final String? application = data['application_id']?.toString();
    final String? code = data['job_code']?.toString();
    // The job seeker's side.
    if (['job_shortlisted', 'job_next_step', 'job_not_selected', 'job_application_closed', 'job_hired'].contains(action) && application != null) {
      return JobApplicationScreen(id: application);
    }
    if (action == 'job_alert' && code != null) return JobScreen(code: code);
    // The employer's side.
    if (['job_application_new', 'job_hire_confirmed', 'job_hire_declined'].contains(action) && application != null) return ApplicantScreen(id: application);
    if (action.startsWith('job_employer_') || ['job_live', 'job_sent_back', 'job_rejected', 'job_closed'].contains(action)) {
      return const MyJobsScreen();
    }
    if (code != null) return JobScreen(code: code);
    return const JobsHomeScreen();
  }
}

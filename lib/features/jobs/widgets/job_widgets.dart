import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/helper/price_converter.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

const Color jobGreen = Color(0xFF15803D);
const Color jobGreenBg = Color(0xFFE9F7EF);
const Color jobBlue = Color(0xFF1D4ED8);
const Color jobBlueBg = Color(0xFFE8EEFC);
const Color jobAmber = Color(0xFFB45309);
const Color jobAmberBg = Color(0xFFFFF4E5);
const Color jobRed = Color(0xFFB91C1C);
const Color jobRedBg = Color(0xFFFDECEC);
const Color jobPrivateFg = Color(0xFF3730A3);
const Color jobPrivateBg = Color(0xFFEEF2FF);

/// "FCFA 60,000 to 75,000 / month"
String jobPay(JobPost job) {
  final min = PriceConverter.convertPrice(job.payMin);
  final amount = job.payMax != null && job.payMax! > job.payMin
      ? 'jobs_pay_range'.trParams({'min': min, 'max': PriceConverter.convertPrice(job.payMax!)})
      : min;
  return '$amount / ${'jobs_per_${job.payPeriod}'.tr}';
}

String jobType(String type) => 'jobs_type_$type'.tr;
String jobCategory(String category) => 'jobs_cat_$category'.tr;

IconData jobCategoryIcon(String category) => switch (category) {
      'sales' => Icons.point_of_sale_rounded,
      'shop_restaurant' => Icons.restaurant_rounded,
      'cleaning' => Icons.cleaning_services_rounded,
      'driving' => Icons.directions_car_rounded,
      'office' => Icons.business_center_rounded,
      'teaching' => Icons.school_rounded,
      'health' => Icons.local_hospital_rounded,
      'building' => Icons.construction_rounded,
      'security' => Icons.security_rounded,
      'beauty' => Icons.content_cut_rounded,
      'tech' => Icons.computer_rounded,
      _ => Icons.work_outline_rounded,
    };

String jobLinkLabel(String type) => 'jobs_link_$type'.tr;

IconData jobLinkIcon(String type) => switch (type) {
      'linkedin' => Icons.work_outline_rounded,
      'github' => Icons.code_rounded,
      'portfolio' => Icons.collections_bookmark_outlined,
      'website' => Icons.language_rounded,
      _ => Icons.link_rounded,
    };

/// "today", "2 days ago"
String jobAgo(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return 'jobs_ago_min'.trParams({'n': '${d.inMinutes < 1 ? 1 : d.inMinutes}'});
  if (d.inHours < 24) return 'jobs_ago_h'.trParams({'n': '${d.inHours}'});
  if (d.inDays == 1) return 'jobs_ago_yesterday'.tr;
  return 'jobs_ago_days'.trParams({'n': '${d.inDays}'});
}

/// "Tue 17 Nov, 10:00"
String jobWhen(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${'market_wd_${t.weekday}'.tr} ${t.day} ${'market_mo_${t.month}'.tr}, ${two(t.hour)}:${two(t.minute)}';
}

class JobLogo extends StatelessWidget {
  final JobEmployer? employer;
  final String category;
  final double size;
  const JobLogo({super.key, this.employer, this.category = 'other', this.size = 48});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (employer?.logo != null) {
      return ImageWidget(image: employer!.logo!, width: size, height: size, radius: size * 0.22, fit: BoxFit.cover);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(size * 0.22)),
      child: Icon(jobCategoryIcon(category), color: theme.primaryColor, size: size * 0.5),
    );
  }
}

class JobTag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const JobTag({super.key, required this.text, this.bg = const Color(0xFFF1F3F3), this.fg = const Color(0xFF48615E), this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 3)],
          Text(text, style: textMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall + 1, color: fg)),
        ]),
      );
}

class JobVerifiedTag extends StatelessWidget {
  const JobVerifiedTag({super.key});

  @override
  Widget build(BuildContext context) => JobTag(text: 'jobs_verified'.tr, bg: jobGreenBg, fg: jobGreen, icon: Icons.verified_rounded);
}

/// A job in a list: who, what, the pay, and where.
class JobCard extends StatelessWidget {
  final JobPost job;
  final VoidCallback onTap;
  const JobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final closingSoon = job.closesAt != null && job.closesAt!.difference(DateTime.now()).inDays < 3 && job.isLive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.hintColor.withValues(alpha: 0.15))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                JobLogo(employer: job.employer, category: job.category, size: 46),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor, height: 1.2)),
                  const SizedBox(height: 2),
                  Text([job.employer?.name ?? '', if (job.area != null) job.area!].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
                ])),
                if (job.applied != null) ...[const SizedBox(width: 6), JobTag(text: 'jobs_applied'.tr, bg: jobBlueBg, fg: jobBlue, icon: Icons.check_rounded)],
              ]),
              const SizedBox(height: 8),
              Text(jobPay(job), style: textBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.primaryColor)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (job.employer?.isVerified ?? false) const JobVerifiedTag(),
                JobTag(text: jobType(job.type)),
                if (job.employer?.isPrivate ?? false) JobTag(text: 'jobs_private_employer'.tr, bg: jobPrivateBg, fg: jobPrivateFg),
                if (job.places > 1) JobTag(text: 'jobs_places_n'.trParams({'n': '${job.places}'})),
                if (closingSoon) JobTag(text: 'jobs_closing_soon'.tr, bg: jobAmberBg, fg: jobAmber, icon: Icons.schedule_rounded),
                if (job.liveAt != null) JobTag(text: jobAgo(job.liveAt), bg: Colors.transparent),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Applying is free; never pay anyone for a job.
class JobNoFeeNotice extends StatelessWidget {
  final String? text;
  const JobNoFeeNotice({super.key, this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: jobGreenBg, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_outlined, color: jobGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text ?? 'jobs_no_fee'.tr, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: jobGreen, height: 1.4))),
        ]),
      );
}

/// Where an application stands, for the person who sent it.
({String label, Color bg, Color fg}) jobApplicationLook(JobApplication a) => switch (a.status) {
      JobApplication.sent => (label: 'jobs_st_sent'.tr, bg: const Color(0xFFF1F3F3), fg: const Color(0xFF48615E)),
      JobApplication.seen => (label: 'jobs_st_seen'.tr, bg: jobBlueBg, fg: jobBlue),
      JobApplication.shortlisted => (label: 'jobs_st_shortlisted'.tr, bg: jobAmberBg, fg: jobAmber),
      JobApplication.nextStepStatus => (label: 'jobs_st_next_step'.tr, bg: jobGreenBg, fg: jobGreen),
      JobApplication.hired => (label: a.hireConfirmed ? 'jobs_st_hired'.tr : 'jobs_st_hired_q'.tr, bg: jobGreenBg, fg: jobGreen),
      JobApplication.notSelected => (label: 'jobs_st_not_selected'.tr, bg: const Color(0xFFF1F3F3), fg: const Color(0xFF6B7675)),
      JobApplication.withdrawn => (label: 'jobs_st_withdrawn'.tr, bg: const Color(0xFFF1F3F3), fg: const Color(0xFF6B7675)),
      _ => (label: 'jobs_st_closed'.tr, bg: const Color(0xFFF1F3F3), fg: const Color(0xFF6B7675)),
    };

/// Sent, Seen, Shortlisted, Next step: four bars that fill as the application moves.
class JobApplicationSteps extends StatelessWidget {
  final JobApplication application;
  const JobApplicationSteps({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = application.status;
    final done = switch (s) {
      JobApplication.sent => 1,
      JobApplication.seen => 2,
      JobApplication.shortlisted => 3,
      JobApplication.nextStepStatus => 4,
      JobApplication.hired => 4,
      _ => application.shortlistedAt != null ? 3 : (application.seenAt != null ? 2 : 1),
    };
    final ended = !application.isOpen && s != JobApplication.nextStepStatus && s != JobApplication.hired;
    final labels = ['jobs_step_sent'.tr, 'jobs_step_seen'.tr, 'jobs_step_shortlist'.tr, 'jobs_step_next'.tr];
    return Column(children: [
      Row(children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: i < done ? (ended ? theme.hintColor.withValues(alpha: 0.5) : (s == JobApplication.nextStepStatus || s == JobApplication.hired ? jobGreen : theme.primaryColor))
                  : theme.hintColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ],
      ]),
      const SizedBox(height: 4),
      Row(children: [
        for (int i = 0; i < 4; i++)
          Expanded(child: Text(labels[i], textAlign: i == 0 ? TextAlign.start : (i == 3 ? TextAlign.end : TextAlign.center),
              style: textRegular.copyWith(fontSize: 10, color: i < done ? theme.textTheme.bodyLarge?.color : theme.hintColor))),
      ]),
    ]);
  }
}

/// A job's state for its employer.
({String label, Color bg, Color fg}) jobPostLook(JobPost j) => switch (j.status) {
      JobPost.review => (label: 'jobs_ps_review'.tr, bg: jobAmberBg, fg: jobAmber),
      JobPost.live => (label: 'jobs_ps_live'.tr, bg: jobGreenBg, fg: jobGreen),
      JobPost.sentBack => (label: 'jobs_ps_sent_back'.tr, bg: jobRedBg, fg: jobRed),
      JobPost.rejected => (label: 'jobs_ps_rejected'.tr, bg: jobRedBg, fg: jobRed),
      JobPost.hidden => (label: 'jobs_ps_hidden'.tr, bg: jobRedBg, fg: jobRed),
      _ => (label: 'jobs_ps_closed'.tr, bg: const Color(0xFFF1F3F3), fg: const Color(0xFF6B7675)),
    };

/// A section title in the Jobs screens.
class JobLabel extends StatelessWidget {
  final String text;
  final String? hint;
  const JobLabel(this.text, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Dimensions.paddingSizeDefault, bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeDefault, color: theme.textTheme.bodyLarge?.color)),
        if (hint != null) Text(hint!, style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
      ]),
    );
  }
}

InputDecoration jobInput(BuildContext context, String hint, {String? suffix}) => InputDecoration(
      hintText: hint,
      suffixText: suffix,
      isDense: true,
      filled: true,
      fillColor: Theme.of(context).cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          borderSide: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: 0.3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          borderSide: BorderSide(color: Theme.of(context).hintColor.withValues(alpha: 0.3))),
    );

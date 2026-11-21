import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/jobs/controllers/jobs_controller.dart';
import 'package:ride_sharing_user_app/features/jobs/domain/models/job_models.dart';
import 'package:ride_sharing_user_app/features/jobs/widgets/job_widgets.dart';
import 'package:ride_sharing_user_app/features/market/widgets/market_service_widgets.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Job alerts: a notification when a verified job fits (a few a day at most).
class JobAlertsScreen extends StatefulWidget {
  const JobAlertsScreen({super.key});

  @override
  State<JobAlertsScreen> createState() => _JobAlertsScreenState();
}

class _JobAlertsScreenState extends State<JobAlertsScreen> {
  bool _enabled = true;
  final Set<String> _categories = {};
  final Set<String> _types = {};
  bool _ready = false;

  JobsController get _jobs => Get.find<JobsController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final a = await _jobs.loadAlert();
      if (!mounted) return;
      setState(() {
        _enabled = a == null || a.enabled || (a.categories.isEmpty && a.types.isEmpty);
        _categories.addAll(a?.categories ?? const []);
        _types.addAll(a?.types ?? const []);
        _ready = true;
      });
    });
  }

  Future<void> _save() async {
    if (await _jobs.saveAlert(_enabled, _categories.toList(), _types.toList()) && mounted) {
      showCustomSnackBar(_enabled ? 'jobs_alerts_on'.tr : 'jobs_alerts_off'.tr, isError: false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final meta = _jobs.meta ?? const JobsMeta();
    final perDay = _jobs.alert?.perDay ?? 2;
    return MarketChips(child: Builder(builder: (context) => Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : theme.colorScheme.surface,
      appBar: AppBar(backgroundColor: theme.cardColor, foregroundColor: textColor, surfaceTintColor: Colors.transparent, title: Text('jobs_alerts'.tr)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: Text('jobs_alerts_switch'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: textColor)),
                subtitle: Text('jobs_alerts_body'.trParams({'n': '$perDay'}), style: textRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: theme.hintColor)),
              ),
              Opacity(
                opacity: _enabled ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !_enabled,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    JobLabel('jobs_alerts_kinds'.tr, hint: 'jobs_alerts_any'.tr),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in meta.categories)
                        FilterChip(
                          avatar: Icon(jobCategoryIcon(c)),
                          label: Text(jobCategory(c)),
                          selected: _categories.contains(c),
                          showCheckmark: false,
                          onSelected: (on) => setState(() => on ? _categories.add(c) : _categories.remove(c)),
                        ),
                    ]),
                    JobLabel('jobs_alerts_types'.tr, hint: 'jobs_alerts_any'.tr),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in meta.types)
                        FilterChip(
                          label: Text(jobType(t)),
                          selected: _types.contains(t),
                          showCheckmark: false,
                          onSelected: (on) => setState(() => on ? _types.add(t) : _types.remove(t)),
                        ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 100),
            ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 8, Dimensions.paddingSizeDefault, 10),
        child: GetBuilder<JobsController>(builder: (c) => SizedBox(height: 52, child: FilledButton(
          onPressed: c.saving || !_ready ? null : _save,
          child: Text('jobs_alerts_save'.tr, style: textSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Colors.white)),
        ))),
      )),
    )));
  }
}

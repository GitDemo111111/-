import 'app_dependencies.dart';
import 'data/web_repositories.dart';
import 'services/reminder_scheduler.dart';
import 'state/contact_controller.dart';
import 'state/settings_controller.dart';

/// Web 预览版：数据存 localStorage，不排系统通知。
///
/// 浏览器里没有应用私有目录，也没有可靠的定时本地通知，所以这里用
/// localStorage + 空调度器。功能逻辑（生日计算、倒计时、筛选排序）与手机端完全一致。
Future<AppDependencies> createAppDependencies() async {
  final SettingsController settingsController = SettingsController(
    repository: WebSettingsRepository(),
  );
  final ContactController contactController = ContactController(
    repository: WebContactRepository(),
    settings: settingsController,
    scheduler: NoopReminderScheduler(),
  );

  return AppDependencies(
    settingsController: settingsController,
    contactController: contactController,
  );
}

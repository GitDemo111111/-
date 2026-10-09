import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/data/contact_repository.dart';
import 'package:birthday_keeper/data/settings_repository.dart';
import 'package:birthday_keeper/services/reminder_scheduler.dart';
import 'package:birthday_keeper/state/contact_controller.dart';
import 'package:birthday_keeper/state/settings_controller.dart';
import 'package:birthday_keeper/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// 测试里固定的「现在」：2026-05-20 10:00。
///
/// 固定时间可以避免测试在跨天 / 跨年时随机失败。
final DateTime kNow = DateTime(2026, 5, 20, 10, 0);

/// 比手机屏幕更高的「测试窗口」。
///
/// 表单页和详情页都是长 ListView，ListView 只会构建可见区域内的子组件，
/// 屏幕外的组件根本不在 widget 树里。把测试窗口调高可以让绝大多数断言直接
/// 生效，不必写一堆脆弱的滚动代码。
const Size kTallViewport = Size(1200, 2600);

/// 和 `testWidgets` 一样，但会把测试窗口调成一块「很高的屏幕」。
@isTest
void widgetTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Size size = kTallViewport,
}) {
  testWidgets(description, (WidgetTester tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await body(tester);
  });
}

/// 接上「系统剪贴板」。
///
/// Widget 测试里没有平台实现，`Clipboard.setData` 会抛 MissingPluginException，
/// 于是复制手机号之类的功能没法测。这里给它一个假的实现，并把调用记录下来。
List<MethodCall> installClipboardMock(WidgetTester tester) {
  final List<MethodCall> calls = <MethodCall>[];
  final TestDefaultBinaryMessenger messenger =
      tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (
    MethodCall call,
  ) async {
    calls.add(call);
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

/// 快速构造一个联系人。
Contact makeContact({
  String id = 'c1',
  String name = '张三',
  Relationship? relationship,
  String? relationLabel,
  Birthday? birthday,
  List<String> hobbies = const <String>[],
  List<String> tags = const <String>[],
  String? phone,
  String? email,
  String? wechat,
  String? notes,
  String? giftIdeas,
  String? avatarEmoji,
  int colorSeed = 0,
  bool favorite = false,
  ReminderSettings reminder = const ReminderSettings(),
  DateTime? createdAt,
}) {
  final DateTime created = createdAt ?? DateTime(2026, 1, 1);
  return Contact(
    id: id,
    name: name,
    relationship: relationship,
    relationLabel: relationLabel,
    birthday: birthday,
    hobbies: hobbies,
    tags: tags,
    phone: phone,
    email: email,
    wechat: wechat,
    notes: notes,
    giftIdeas: giftIdeas,
    avatarEmoji: avatarEmoji,
    colorSeed: colorSeed,
    favorite: favorite,
    reminder: reminder,
    createdAt: created,
    updatedAt: created,
  );
}

/// 组装一套完全内存化的依赖，供单元测试与 Widget 测试使用。
class TestHarness {
  TestHarness({
    List<Contact> contacts = const <Contact>[],
    AppSettings settings = const AppSettings(),
    DateTime? now,
    bool permissionGranted = true,
  }) : _now = now ?? kNow {
    contactRepository = InMemoryContactRepository(contacts);
    settingsRepository = InMemorySettingsRepository(settings);
    scheduler = NoopReminderScheduler(permissionGranted: permissionGranted);
    settingsController = SettingsController(repository: settingsRepository);
    contactController = ContactController(
      repository: contactRepository,
      settings: settingsController,
      scheduler: scheduler,
      clock: () => _now,
    );
  }

  final DateTime _now;

  late final InMemoryContactRepository contactRepository;
  late final InMemorySettingsRepository settingsRepository;
  late final NoopReminderScheduler scheduler;
  late final SettingsController settingsController;
  late final ContactController contactController;

  DateTime get now => _now;

  /// 读取本地数据（等价于 App 启动）。
  Future<void> load() async {
    await settingsController.load();
    await contactController.load();
  }

  /// 把一个页面包进和真实 App 一致的 MaterialApp 环境里。
  Widget wrap(Widget page) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
        ChangeNotifierProvider<ContactController>.value(
          value: contactController,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: page,
      ),
    );
  }
}

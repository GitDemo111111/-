import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('默认值', () {
    test('默认开启提醒，默认提前 3 天', () {
      const AppSettings settings = AppSettings();
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.defaultReminder, const ReminderSettings());
      expect(settings.defaultReminder.daysBefore, 3);
      expect(settings.sortMode, ContactSortMode.daysUntil);
      expect(settings.showLunarInfo, isTrue);
      expect(settings.groupUpcoming, isTrue);
    });
  });

  group('ContactSortMode', () {
    test('每种模式都有中文名', () {
      for (final ContactSortMode mode in ContactSortMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });

    test('fromName 容错', () {
      expect(ContactSortMode.fromName('name'), ContactSortMode.name);
      expect(
        ContactSortMode.fromName('recentlyUpdated'),
        ContactSortMode.recentlyUpdated,
      );
      expect(ContactSortMode.fromName('乱写'), ContactSortMode.daysUntil);
      expect(ContactSortMode.fromName(null), ContactSortMode.daysUntil);
    });
  });

  group('JSON', () {
    test('往返一致', () {
      const AppSettings original = AppSettings(
        notificationsEnabled: false,
        defaultReminder: ReminderSettings(daysBefore: 7, hour: 20, minute: 30),
        sortMode: ContactSortMode.name,
        showLunarInfo: false,
        groupUpcoming: false,
      );
      expect(AppSettings.fromJson(original.toJson()), original);
    });

    test('空数据回退到默认值', () {
      expect(AppSettings.fromJson(<String, Object?>{}), const AppSettings());
    });

    test('脏数据回退到默认值', () {
      final AppSettings parsed = AppSettings.fromJson(<String, Object?>{
        'notificationsEnabled': 'yes',
        'defaultReminder': 'not-a-map',
        'sortMode': 42,
        'showLunarInfo': null,
      });
      expect(parsed.notificationsEnabled, isTrue);
      expect(parsed.defaultReminder, const ReminderSettings());
      expect(parsed.sortMode, ContactSortMode.daysUntil);
      expect(parsed.showLunarInfo, isTrue);
    });

    test('内部提醒设置也会被解析', () {
      final AppSettings parsed = AppSettings.fromJson(<String, Object?>{
        'defaultReminder': <String, Object?>{
          'enabled': true,
          'daysBefore': 1,
          'notifyOnDay': false,
          'hour': 8,
          'minute': 15,
        },
      });
      expect(parsed.defaultReminder.daysBefore, 1);
      expect(parsed.defaultReminder.notifyOnDay, isFalse);
      expect(parsed.defaultReminder.timeLabel, '08:15');
    });
  });

  group('copyWith', () {
    test('只改指定字段', () {
      const AppSettings original = AppSettings();
      final AppSettings updated = original.copyWith(
        sortMode: ContactSortMode.name,
      );
      expect(updated.sortMode, ContactSortMode.name);
      expect(updated.notificationsEnabled, original.notificationsEnabled);
      expect(updated.defaultReminder, original.defaultReminder);
    });
  });

  test('相等性与 hashCode', () {
    expect(const AppSettings(), const AppSettings());
    expect(
      const AppSettings(),
      isNot(const AppSettings(notificationsEnabled: false)),
    );
    expect(const AppSettings().hashCode, const AppSettings().hashCode);
  });
}

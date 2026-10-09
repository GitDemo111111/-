import 'package:meta/meta.dart';

import '../models/birthday.dart';
import '../models/contact.dart';
import 'birthday_calculator.dart';
import 'date_x.dart';

/// 提醒的种类。
enum ReminderKind {
  /// 生日前的提前提醒（默认提前 3 天）。
  advance('提前提醒'),

  /// 生日当天的提醒。
  onDay('当天提醒');

  const ReminderKind(this.label);

  final String label;
}

/// 一条待调度的本地通知。
@immutable
class PendingReminder {
  const PendingReminder({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.kind,
    required this.scheduledAt,
    required this.occurrenceDate,
    required this.title,
    required this.body,
  });

  /// 通知 id，必须是 32 位有符号整数。
  final int id;
  final String contactId;
  final String contactName;
  final ReminderKind kind;

  /// 实际触发时间。
  final DateTime scheduledAt;

  /// 对应的生日日期。
  final DateTime occurrenceDate;

  final String title;
  final String body;

  /// 点击通知后要打开的联系人。
  String get payload => contactId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PendingReminder && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PendingReminder($id, $contactName, ${kind.name}, $scheduledAt)';
}

/// 32 位 FNV-1a，取低 28 位；同一个 id 每次都得到同样的结果。
int _stableHash28(String key) {
  int hash = 2166136261;
  for (final int unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return hash & 0x0FFFFFFF;
}

/// 通知 id 的生成规则：28 位基址 × 4 + 槽位，保证是正的 32 位整数。
///
/// 之所以要「稳定」，是因为新增/删除联系人后需要能精确取消旧通知。
int notificationIdFor(
  String contactId,
  ReminderKind kind,
  int occurrenceIndex,
) {
  final int base = _stableHash28(contactId);
  final int slot =
      (kind.index + occurrenceIndex * ReminderKind.values.length) % 4;
  return base * 4 + slot;
}

/// 把「联系人 + 当前时间」换算成一组待调度的通知。
///
/// 这是一个纯函数：同样的输入永远得到同样的输出，方便单测。
class ReminderPlanner {
  const ReminderPlanner({
    this.calculator = const BirthdayCalculator(),
    this.occurrencesAhead = 2,
    this.immediateLead = const Duration(minutes: 1),
  });

  final BirthdayCalculator calculator;

  /// 为每位联系人预先排多少次生日（覆盖今年和明年，避免长期不打开 App 就漏提醒）。
  final int occurrencesAhead;

  /// 提前提醒的日期已经过去、但生日还没到时，延迟多久立刻提醒。
  final Duration immediateLead;

  /// 生成所有待调度提醒，按触发时间升序排序。
  List<PendingReminder> plan({
    required List<Contact> contacts,
    required DateTime now,
  }) {
    final List<PendingReminder> result = <PendingReminder>[];
    final DateTime today = dateOnly(now);
    final int ahead = occurrencesAhead.clamp(1, 2).toInt();

    for (final Contact contact in contacts) {
      final Birthday? birthday = contact.birthday;
      if (birthday == null) continue;

      final ReminderSettings reminder = contact.reminder;
      if (!reminder.enabled) continue;
      if (reminder.daysBefore <= 0 && !reminder.notifyOnDay) continue;

      final List<BirthdayOccurrence> occurrences = calculator.nextOccurrences(
        birthday,
        today,
        ahead,
      );

      for (int index = 0; index < occurrences.length; index++) {
        final BirthdayOccurrence occurrence = occurrences[index];
        final int daysUntil = daysBetween(today, occurrence.date);
        final int? turningAge = calculator.ageAt(birthday, occurrence);

        // 提前 N 天的提醒
        if (reminder.daysBefore > 0 && daysUntil > 0) {
          final DateTime advanceDay = DateTime(
            occurrence.date.year,
            occurrence.date.month,
            occurrence.date.day - reminder.daysBefore,
          );
          final DateTime planned = DateTime(
            advanceDay.year,
            advanceDay.month,
            advanceDay.day,
            reminder.hour,
            reminder.minute,
          );
          // 提前提醒的时间点已经过去（例如刚添加联系人时生日只剩 1 天），
          // 就立刻提醒一次，而不是默默错过。
          final DateTime scheduledAt = planned.isAfter(now)
              ? planned
              : now.add(immediateLead);
          result.add(
            PendingReminder(
              id: notificationIdFor(contact.id, ReminderKind.advance, index),
              contactId: contact.id,
              contactName: contact.name,
              kind: ReminderKind.advance,
              scheduledAt: scheduledAt,
              occurrenceDate: occurrence.date,
              title: '🎂 ${contact.name}的生日快到了',
              body: _advanceBody(contact.name, daysUntil, turningAge),
            ),
          );
        }

        // 当天提醒
        if (reminder.notifyOnDay) {
          final DateTime onDay = DateTime(
            occurrence.date.year,
            occurrence.date.month,
            occurrence.date.day,
            reminder.hour,
            reminder.minute,
          );
          if (onDay.isAfter(now)) {
            result.add(
              PendingReminder(
                id: notificationIdFor(contact.id, ReminderKind.onDay, index),
                contactId: contact.id,
                contactName: contact.name,
                kind: ReminderKind.onDay,
                scheduledAt: onDay,
                occurrenceDate: occurrence.date,
                title: '🎉 今天是${contact.name}的生日',
                body: _onDayBody(contact.name, turningAge),
              ),
            );
          }
        }
      }
    }

    result.sort((PendingReminder a, PendingReminder b) {
      final int byTime = a.scheduledAt.compareTo(b.scheduledAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return result;
  }

  String _advanceBody(String name, int daysUntil, int? turningAge) {
    final StringBuffer buffer = StringBuffer('还有 $daysUntil 天是$name的生日');
    if (turningAge != null) buffer.write('（将满 $turningAge 岁）');
    buffer.write('，记得准备祝福或礼物～');
    return buffer.toString();
  }

  String _onDayBody(String name, int? turningAge) {
    final StringBuffer buffer = StringBuffer('别忘了送上生日祝福');
    if (turningAge != null) {
      buffer.write('，$name今天就满 $turningAge 岁啦');
    }
    buffer.write('！');
    return buffer.toString();
  }
}

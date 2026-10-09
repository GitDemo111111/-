import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/birthday_calculator.dart';
import '../../core/formatters.dart';
import '../../core/lunar_converter.dart';
import '../../models/birthday.dart';
import '../../models/contact.dart';
import '../../state/contact_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/visuals.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/forms.dart';

/// 联系人详情。
class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();
    final Contact? contact = controller.contactById(contactId);

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: '联系人不存在',
          message: '可能已经被删除了。',
        ),
      );
    }

    final UpcomingBirthday? item = controller.upcomingForId(contact.id);
    final Birthday? birthday = contact.birthday;
    final LunarDate? lunarDate = item == null
        ? null
        : controller.calculator.lunarDateOf(item.date);
    final String? constellation = birthday == null
        ? null
        : controller.calculator.constellation(birthday, controller.now);
    final String? zodiac = birthday == null
        ? null
        : controller.calculator.chineseZodiac(birthday);

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        actions: <Widget>[
          IconButton(
            key: const Key('detailFavoriteButton'),
            tooltip: contact.favorite ? '取消星标' : '设为星标',
            onPressed: () => controller.toggleFavorite(contact.id),
            icon: Icon(
              contact.favorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: contact.favorite ? const Color(0xFFFFB020) : null,
            ),
          ),
          IconButton(
            key: const Key('detailEditButton'),
            tooltip: '编辑',
            onPressed: () => openContactEditor(context, contactId: contact.id),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const Key('detailDeleteButton'),
            tooltip: '删除',
            onPressed: () => _confirmDelete(context, controller, contact),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: <Widget>[
          _ProfileCard(contact: contact),
          const SizedBox(height: 14),
          if (item != null)
            _CountdownCard(
              item: item,
              birthday: birthday!,
              lunarDate: lunarDate,
              constellation: constellation,
              zodiac: zodiac,
              showLunar: controller.settings.showLunarInfo,
            )
          else
            const AppCard(
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_busy_outlined,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '还没有记录生日，点右上角「编辑」补上吧',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _ReminderCard(contact: contact),
          if (_hasContactInfo(contact)) ...<Widget>[
            const SizedBox(height: 14),
            _InfoCard(contact: contact),
          ],
          if (contact.hobbies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _ChipsCard(
              title: '爱好',
              icon: Icons.interests_rounded,
              values: contact.hobbies,
            ),
          ],
          if (_nonEmpty(contact.giftIdeas) != null) ...<Widget>[
            const SizedBox(height: 14),
            _TextCard(
              title: '礼物灵感',
              icon: Icons.card_giftcard_rounded,
              text: contact.giftIdeas!,
            ),
          ],
          if (_nonEmpty(contact.notes) != null) ...<Widget>[
            const SizedBox(height: 14),
            _TextCard(
              title: '备注',
              icon: Icons.sticky_note_2_outlined,
              text: contact.notes!,
            ),
          ],
          if (contact.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _ChipsCard(
              title: '标签',
              icon: Icons.label_outline_rounded,
              values: contact.tags,
            ),
          ],
        ],
      ),
    );
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _hasContactInfo(Contact contact) =>
      _nonEmpty(contact.phone) != null ||
      _nonEmpty(contact.wechat) != null ||
      _nonEmpty(contact.email) != null;

  Future<void> _confirmDelete(
    BuildContext context,
    ContactController controller,
    Contact contact,
  ) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: '删除联系人',
      message: '确定要删除「${contact.name}」吗？该联系人的提醒也会一起取消。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    await controller.deleteContact(contact.id);
    if (!context.mounted) return;
    showAppSnackBar(context, '已删除 ${contact.name}');
    navigator.pop();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? relation = contact.relationshipLabel;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          ContactAvatar(contact: contact, size: 68),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  contact.name,
                  style: text.headlineSmall?.copyWith(fontSize: 22),
                ),
                if (relation != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          relationshipIcon(contact.relationship),
                          size: 14,
                          color: AppColors.brandDark,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          relation,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.item,
    required this.birthday,
    required this.lunarDate,
    required this.constellation,
    required this.zodiac,
    required this.showLunar,
  });

  final UpcomingBirthday item;
  final Birthday birthday;
  final LunarDate? lunarDate;
  final String? constellation;
  final String? zodiac;
  final bool showLunar;

  @override
  Widget build(BuildContext context) {
    final bool isToday = item.isToday;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isToday
              ? const <Color>[Color(0xFFFF5A8A), Color(0xFFFF8A3D)]
              : const <Color>[AppColors.brand, AppColors.brandLight],
        ),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (isToday)
                const Text(
                  '🎉 今天生日',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else ...<Widget>[
                Text(
                  '${item.daysUntil}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 6, bottom: 6),
                  child: Text(
                    '天后生日',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (item.turningAge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '将满 ${item.turningAge} 岁',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${formatFullDate(item.date)} ${weekdayLabel(item.date)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isToday ? '记得送上生日祝福～' : _birthdayDescription(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _InfoPill(
                text: birthday.isLunar
                    ? birthday.shortLabel
                    : '新历${birthday.shortLabel}',
              ),
              if (showLunar && birthday.isSolar && lunarDate != null)
                _InfoPill(text: lunarDate!.label),
              if (constellation != null) _InfoPill(text: constellation!),
              if (zodiac != null) _InfoPill(text: '属$zodiac'),
            ],
          ),
        ],
      ),
    );
  }

  String _birthdayDescription() {
    final List<String> parts = <String>['还有 ${item.daysUntil} 天'];
    if (item.turningAge != null) parts.add('就要满 ${item.turningAge} 岁啦');
    return parts.join('，');
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final bool enabled = contact.reminder.enabled && contact.hasBirthday;
    return AppCard(
      child: Row(
        children: <Widget>[
          Icon(
            enabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_outlined,
            color: enabled ? AppColors.brand : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '提醒',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  contact.hasBirthday ? contact.reminder.summary : '还没有生日，无法提醒',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          if (ContactDetailPage._nonEmpty(contact.phone) != null)
            InfoRow(
              icon: Icons.phone_rounded,
              label: '手机',
              value: contact.phone!,
              onTap: () => _copy(context, contact.phone!, '手机号'),
            ),
          if (ContactDetailPage._nonEmpty(contact.wechat) != null)
            InfoRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: '微信',
              value: contact.wechat!,
              onTap: () => _copy(context, contact.wechat!, '微信号'),
            ),
          if (ContactDetailPage._nonEmpty(contact.email) != null)
            InfoRow(
              icon: Icons.mail_outline_rounded,
              label: '邮箱',
              value: contact.email!,
              onTap: () => _copy(context, contact.email!, '邮箱'),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    showAppSnackBar(context, '已复制$label');
  }
}

class _ChipsCard extends StatelessWidget {
  const _ChipsCard({
    required this.title,
    required this.icon,
    required this.values,
  });

  final String title;
  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(icon: icon, title: title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String value in values)
                SelectableChip(
                  label: value,
                  selected: false,
                  dense: true,
                  onTap: null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(icon: icon, title: title),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 14.5, height: 1.5)),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 17, color: AppColors.brand),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}

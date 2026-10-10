import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/contact_text_parser.dart';
import '../../core/lunar_names.dart';
import '../../models/birthday.dart';
import '../../models/contact.dart';
import '../../models/hobbies.dart';
import '../../models/relationship.dart';
import '../../state/contact_controller.dart';
import '../../state/root_tab_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/visuals.dart';
import '../navigation.dart';
import '../widgets/birthday_facts.dart';
import '../widgets/contact_text_help.dart';
import '../widgets/forms.dart';
import 'contact_import_page.dart';

/// 新建 / 编辑联系人。
///
/// 除了姓名之外的所有字段都可以留空 —— 不知道就不填。
class ContactEditPage extends StatefulWidget {
  const ContactEditPage({super.key, this.contactId});

  /// 为空表示新建。
  final String? contactId;

  @override
  State<ContactEditPage> createState() => _ContactEditPageState();
}

class _ContactEditPageState extends State<ContactEditPage> {
  static const List<String> _avatarChoices = <String>[
    '😀',
    '😎',
    '🥰',
    '🎂',
    '🌸',
    '⭐',
    '🐱',
    '🐶',
    '🍰',
    '☕',
    '🎵',
    '⚽',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _relationLabel = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _wechat = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _giftIdeas = TextEditingController();

  Relationship? _relationship;

  /// 关系选择器当前展开的分组（二级选择：先选组，再选具体角色）。
  RelationshipGroup? _relationGroup = RelationshipGroup.family;

  BirthdayCalendar _calendar = BirthdayCalendar.solar;
  DateTime? _solarDate;
  bool _yearUnknown = false;
  int _lunarMonth = 1;
  int _lunarDay = 1;
  bool _lunarLeap = false;
  int _lunarYear = 1995;

  /// 用户是否真的选过农历生日（避免一选「农历」就凭空多出一个生日）。
  bool _lunarSet = false;
  final Set<String> _hobbies = <String>{};
  final Set<String> _tags = <String>{};
  ReminderSettings _reminder = const ReminderSettings();
  bool _favorite = false;
  String? _avatarEmoji;
  bool _saving = false;
  String? _birthdayError;

  Contact? _existing;
  bool _initialised = false;

  bool get _isEditing => _existing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;

    final ContactController controller = context.read<ContactController>();
    final Contact? existing = widget.contactId == null
        ? null
        : controller.contactById(widget.contactId!);
    _existing = existing;

    if (existing == null) {
      _reminder = controller.defaultReminder;
      return;
    }

    _name.text = existing.name;
    _relationLabel.text = existing.relationLabel ?? '';
    _phone.text = existing.phone ?? '';
    _email.text = existing.email ?? '';
    _wechat.text = existing.wechat ?? '';
    _notes.text = existing.notes ?? '';
    _giftIdeas.text = existing.giftIdeas ?? '';
    _relationship = existing.relationship;
    _relationGroup = existing.relationship?.group ?? RelationshipGroup.family;
    _hobbies.addAll(existing.hobbies);
    _tags.addAll(existing.tags);
    _reminder = existing.reminder;
    _favorite = existing.favorite;
    _avatarEmoji = existing.avatarEmoji;

    final Birthday? birthday = existing.birthday;
    if (birthday != null) {
      _calendar = birthday.calendar;
      _yearUnknown = !birthday.hasYear;
      if (birthday.isSolar) {
        _solarDate = DateTime(
          birthday.year ?? kReferenceLeapYear,
          birthday.month,
          birthday.day,
        );
      } else {
        _lunarMonth = birthday.month;
        _lunarDay = birthday.day;
        _lunarLeap = birthday.isLeapMonth;
        _lunarYear = birthday.year ?? 1995;
        _lunarSet = true;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _relationLabel.dispose();
    _phone.dispose();
    _email.dispose();
    _wechat.dispose();
    _notes.dispose();
    _giftIdeas.dispose();
    super.dispose();
  }

  static String? _emptyToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Birthday? _buildBirthday() {
    if (_calendar == BirthdayCalendar.solar) {
      final DateTime? date = _solarDate;
      if (date == null) return null;
      return Birthday(
        month: date.month,
        day: date.day,
        year: _yearUnknown ? null : date.year,
        calendar: BirthdayCalendar.solar,
      );
    }
    if (!_lunarSet) return null;
    return Birthday(
      month: _lunarMonth,
      day: _lunarDay,
      year: _yearUnknown ? null : _lunarYear,
      calendar: BirthdayCalendar.lunar,
      isLeapMonth: _lunarLeap,
    );
  }

  Future<void> _pickSolarDate() async {
    final DateTime now = context.read<ContactController>().now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _solarDate ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '选择生日',
      fieldLabelText: '生日',
    );
    if (picked == null) return;
    setState(() {
      _solarDate = picked;
      _birthdayError = null;
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
      helpText: '选择提醒时间',
    );
    if (picked == null) return;
    setState(() {
      _reminder = _reminder.copyWith(hour: picked.hour, minute: picked.minute);
    });
  }

  /// 用「粘贴文本」的方式自动填充表单。
  Future<void> _fillFromText() async {
    final ContactTextFillResult? result = await showContactTextFillDialog(
      context,
      defaultCalendar: context
          .read<SettingsController>()
          .settings
          .importCalendar,
    );
    if (result == null || !mounted) return;

    // 文本里有好几位 -> 交给「从文本导入」页批量导入，这里就不填了。
    final String? batchText = result.batchText;
    if (batchText != null) {
      final NavigatorState navigator = Navigator.of(context);
      navigator.pop();
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) =>
              ContactImportPage(initialText: batchText),
        ),
      );
      return;
    }

    final ParsedContact? parsed = result.contact;
    if (parsed == null) return;

    setState(() {
      if (parsed.name.trim().isNotEmpty) _name.text = parsed.name.trim();
      if (parsed.relationship != null) {
        _relationship = parsed.relationship;
        _relationGroup = parsed.relationship!.group;
      }
      if (parsed.relationLabel != null) {
        _relationLabel.text = parsed.relationLabel!;
      }
      if (parsed.hobbies.isNotEmpty) {
        _hobbies
          ..clear()
          ..addAll(parsed.hobbies);
      }
      if (parsed.tags.isNotEmpty) {
        _tags
          ..clear()
          ..addAll(parsed.tags);
      }
      if (parsed.phone != null) _phone.text = parsed.phone!;
      if (parsed.email != null) _email.text = parsed.email!;
      if (parsed.wechat != null) _wechat.text = parsed.wechat!;
      if (parsed.notes != null) _notes.text = parsed.notes!;
      if (parsed.giftIdeas != null) _giftIdeas.text = parsed.giftIdeas!;
      if (parsed.avatarEmoji != null) _avatarEmoji = parsed.avatarEmoji;

      final Birthday? birthday = parsed.birthday;
      if (birthday != null) {
        _calendar = birthday.calendar;
        _yearUnknown = !birthday.hasYear;
        _birthdayError = null;
        if (birthday.isSolar) {
          _solarDate = DateTime(
            birthday.year ?? kReferenceLeapYear,
            birthday.month,
            birthday.day,
          );
        } else {
          _lunarMonth = birthday.month;
          _lunarDay = birthday.day;
          _lunarLeap = birthday.isLeapMonth;
          _lunarYear = birthday.year ?? 1995;
          _lunarSet = true;
        }
      }
    });
    if (!mounted) return;
    showAppSnackBar(context, '已按文本填充，请核对后保存');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final Birthday? birthday = _buildBirthday();
    final String? birthdayError = birthday?.validate();
    if (birthdayError != null) {
      setState(() => _birthdayError = birthdayError);
      return;
    }

    setState(() {
      _saving = true;
      _birthdayError = null;
    });

    final ContactController controller = context.read<ContactController>();
    final DateTime now = controller.now;
    final Contact contact = Contact(
      id: _existing?.id ?? controller.newContactId(),
      name: _name.text.trim(),
      relationship: _relationship,
      relationLabel: _emptyToNull(_relationLabel.text),
      birthday: birthday,
      hobbies: _hobbies.toList(),
      tags: _tags.toList(),
      phone: _emptyToNull(_phone.text),
      email: _emptyToNull(_email.text),
      wechat: _emptyToNull(_wechat.text),
      notes: _emptyToNull(_notes.text),
      giftIdeas: _emptyToNull(_giftIdeas.text),
      avatarEmoji: _avatarEmoji,
      colorSeed: _existing?.colorSeed ?? 0,
      favorite: _favorite,
      reminder: _reminder,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (_isEditing) {
      await controller.updateContact(contact);
    } else {
      await controller.addContact(contact);
    }

    if (!mounted) return;

    showAppSnackBar(context, _isEditing ? '已保存' : '已添加 ${contact.name}');
    // 保存后自动回到「联系人」页，方便立刻看到刚保存的人
    context.read<RootTabController>().goToContacts();
    Navigator.of(context).pop();
    // 通知权限弹窗放在导航之后：不能让系统弹窗把用户卡在编辑页
    if (contact.reminder.enabled && controller.settings.notificationsEnabled) {
      unawaited(controller.requestNotificationPermission());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑联系人' : '新建联系人'),
        actions: <Widget>[
          IconButton(
            key: const Key('fillFromTextButton'),
            tooltip: '粘贴文本自动填充',
            onPressed: _saving ? null : _fillFromText,
            icon: const Icon(Icons.content_paste_go_rounded),
          ),
          TextButton(
            key: const Key('saveButton'),
            onPressed: _saving ? null : _save,
            child: const Text(
              '保存',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: <Widget>[
            _Section(
              title: '基本信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    key: const Key('nameField'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '姓名 / 昵称',
                      hintText: '必填',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (String? value) =>
                        (value == null || value.trim().isEmpty)
                        ? '请填写姓名'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('关系 / 身份（可不填）'),
                  const SizedBox(height: 8),
                  // 一级：先选分组（家人 / 亲戚 / 朋友 / 同事 / 同学 / 其他）
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final RelationshipGroup group
                          in RelationshipGroup.values)
                        SelectableChip(
                          key: Key('relationGroup-${group.name}'),
                          label: group.label,
                          icon: relationshipGroupIcon(group),
                          dense: true,
                          selected: _relationGroup == group,
                          onTap: () => setState(() {
                            _relationGroup = _relationGroup == group
                                ? null
                                : group;
                          }),
                        ),
                    ],
                  ),
                  // 二级：该分组下的具体角色（家人 -> 爸爸 / 妈妈 / 爷爷 …）
                  if (_relationGroup != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(
                          AppSizes.fieldRadius,
                        ),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final Relationship item
                              in _relationGroup!.members)
                            SelectableChip(
                              key: Key('relationChip-${item.name}'),
                              label: item.label,
                              icon: relationshipIcon(item),
                              dense: true,
                              selected: _relationship == item,
                              onTap: () => setState(() {
                                _relationship = _relationship == item
                                    ? null
                                    : item;
                                _relationGroup = item.group;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_relationship != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '已选：${_relationship!.label}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandDark,
                          ),
                        ),
                        TextButton(
                          key: const Key('clearRelationshipButton'),
                          onPressed: () => setState(() => _relationship = null),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('relationLabelField'),
                    controller: _relationLabel,
                    decoration: const InputDecoration(
                      labelText: '更具体的身份（选填）',
                      hintText: '例如：大学室友、产品经理',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('头像'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      SelectableChip(
                        label: '默认',
                        dense: true,
                        selected: _avatarEmoji == null,
                        onTap: () => setState(() => _avatarEmoji = null),
                      ),
                      for (final String emoji in _avatarChoices)
                        _EmojiChip(
                          emoji: emoji,
                          selected: _avatarEmoji == emoji,
                          onTap: () => setState(
                            () => _avatarEmoji = _avatarEmoji == emoji
                                ? null
                                : emoji,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _Section(
              title: '生日',
              subtitle: '不填也没关系，可以之后再补',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SelectableChip(
                          key: const Key('calendarSolar'),
                          label: '新历',
                          selected: _calendar == BirthdayCalendar.solar,
                          onTap: () => setState(() {
                            _calendar = BirthdayCalendar.solar;
                            _birthdayError = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableChip(
                          key: const Key('calendarLunar'),
                          label: '农历',
                          selected: _calendar == BirthdayCalendar.lunar,
                          onTap: () => setState(() {
                            _calendar = BirthdayCalendar.lunar;
                            _birthdayError = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_calendar == BirthdayCalendar.solar)
                    _SolarBirthdayField(
                      date: _solarDate,
                      onTap: _pickSolarDate,
                      onClear: () => setState(() {
                        _solarDate = null;
                        _birthdayError = null;
                      }),
                    )
                  else
                    _LunarBirthdayFields(
                      hasValue: _lunarSet,
                      month: _lunarMonth,
                      day: _lunarDay,
                      isLeapMonth: _lunarLeap,
                      onMonthChanged: (int value) => setState(() {
                        _lunarMonth = value;
                        _lunarSet = true;
                      }),
                      onDayChanged: (int value) => setState(() {
                        _lunarDay = value;
                        _lunarSet = true;
                      }),
                      onLeapChanged: (bool value) => setState(() {
                        _lunarLeap = value;
                        _lunarSet = true;
                      }),
                      onClear: () => setState(() {
                        _lunarMonth = 1;
                        _lunarDay = 1;
                        _lunarLeap = false;
                        _lunarSet = false;
                        _birthdayError = null;
                      }),
                    ),
                  if (birthdayOrNullIsSet) ...<Widget>[
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      key: const Key('yearUnknownSwitch'),
                      contentPadding: EdgeInsets.zero,
                      value: _yearUnknown,
                      onChanged: (bool value) =>
                          setState(() => _yearUnknown = value),
                      title: const Text(
                        '不知道出生年份',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        '开启后只记录月日，不显示年龄',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                  if (_calendar == BirthdayCalendar.lunar &&
                      !_yearUnknown &&
                      birthdayOrNullIsSet)
                    _YearStepper(
                      year: _lunarYear,
                      onChanged: (int value) =>
                          setState(() => _lunarYear = value),
                    ),
                  if (_birthdayError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _birthdayError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  // 星座 / 生肖 / 农历都由生日自动算出来，用户不用填。
                  if (_liveFactsBirthday != null) ...<Widget>[
                    const SizedBox(height: 12),
                    const _FieldLabel('自动识别'),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (BuildContext context) => BirthdayFacts(
                        birthday: _liveFactsBirthday!,
                        calculator: context
                            .read<ContactController>()
                            .calculator,
                        now: context.read<ContactController>().now,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              title: '爱好',
              subtitle: '选填，用于挑礼物时找灵感',
              child: TagSelector(
                addKey: const Key('addHobbyChip'),
                options: <String>{...kPresetHobbies, ..._hobbies}.toList(),
                selected: _hobbies,
                onToggle: (String value) => setState(() {
                  if (!_hobbies.remove(value)) _hobbies.add(value);
                }),
                onAdd: (String value) => setState(() => _hobbies.add(value)),
                addLabel: '爱好',
              ),
            ),
            _Section(
              title: '其他关键信息',
              subtitle: '都可不填',
              child: Column(
                children: <Widget>[
                  TextFormField(
                    key: const Key('phoneField'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('wechatField'),
                    controller: _wechat,
                    decoration: const InputDecoration(
                      labelText: '微信 / QQ',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('emailField'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('giftIdeasField'),
                    controller: _giftIdeas,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '礼物灵感',
                      hintText: '例如：喜欢手冲咖啡、想要一本画册',
                      prefixIcon: Icon(Icons.card_giftcard_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('notesField'),
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      hintText: '忌口、过敏、其他要记住的事',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: '标签',
              subtitle: '方便筛选，选填',
              child: TagSelector(
                addKey: const Key('addTagChip'),
                options: <String>{...kPresetTags, ..._tags}.toList(),
                selected: _tags,
                onToggle: (String value) => setState(() {
                  if (!_tags.remove(value)) _tags.add(value);
                }),
                onAdd: (String value) => setState(() => _tags.add(value)),
                addLabel: '标签',
              ),
            ),
            _Section(
              title: '提醒',
              subtitle: '默认生日前 3 天和当天提醒',
              child: Column(
                children: <Widget>[
                  SwitchListTile.adaptive(
                    key: const Key('reminderEnabledSwitch'),
                    contentPadding: EdgeInsets.zero,
                    value: _reminder.enabled,
                    onChanged: (bool value) => setState(() {
                      _reminder = _reminder.copyWith(enabled: value);
                    }),
                    title: const Text(
                      '开启提醒',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_reminder.enabled) ...<Widget>[
                    const Divider(height: 18),
                    Row(
                      children: <Widget>[
                        const Text(
                          '提前',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Expanded(
                          child: Slider(
                            key: const Key('daysBeforeSlider'),
                            value: _reminder.daysBefore.toDouble(),
                            min: 0,
                            max: 30,
                            divisions: 30,
                            label: _reminder.daysBefore == 0
                                ? '当天'
                                : '${_reminder.daysBefore} 天',
                            onChanged: (double value) => setState(() {
                              _reminder = _reminder.copyWith(
                                daysBefore: value.round(),
                              );
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            _reminder.daysBefore == 0
                                ? '当天'
                                : '${_reminder.daysBefore} 天',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      key: const Key('notifyOnDaySwitch'),
                      contentPadding: EdgeInsets.zero,
                      value: _reminder.notifyOnDay,
                      onChanged: (bool value) => setState(() {
                        _reminder = _reminder.copyWith(notifyOnDay: value);
                      }),
                      title: const Text(
                        '生日当天也提醒',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ListTile(
                      key: const Key('remindTimeTile'),
                      contentPadding: EdgeInsets.zero,
                      onTap: _pickTime,
                      leading: const Icon(
                        Icons.access_time_rounded,
                        color: AppColors.brand,
                      ),
                      title: const Text(
                        '提醒时间',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        _reminder.timeLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              title: '其他',
              child: SwitchListTile.adaptive(
                key: const Key('favoriteSwitch'),
                contentPadding: EdgeInsets.zero,
                value: _favorite,
                onChanged: (bool value) => setState(() => _favorite = value),
                title: const Text(
                  '标记为星标联系人',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '星标联系人会排在列表前面',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isEditing ? '保存修改' : '添加联系人'),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前表单里「合法且已设置」的生日，用于实时展示星座/生肖/农历。
  Birthday? get _liveFactsBirthday {
    final Birthday? birthday = _buildBirthday();
    if (birthday == null) return null;
    return birthday.validate() == null ? birthday : null;
  }

  /// 是否已经选过生日（决定是否显示「不知道年份」等附加选项）。
  bool get birthdayOrNullIsSet =>
      _calendar == BirthdayCalendar.solar ? _solarDate != null : _lunarSet;
}

// ------------------------------------------------------------------ 子组件

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: AppColors.outline),
        ),
        // ListTile / SwitchListTile 需要最近的 Material 祖先来绘制水波纹和背景，
        // 否则 Flutter 会断言「ink splashes may be invisible」。
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSizes.chipRadius),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.outline,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 17)),
      ),
    );
  }
}

class _SolarBirthdayField extends StatelessWidget {
  const _SolarBirthdayField({
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bool hasValue = date != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.event_rounded, size: 20, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasValue
                  ? '${date!.year} 年 ${date!.month} 月 ${date!.day} 日'
                  : '还没有选择生日',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: hasValue
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (hasValue)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: '清除',
            ),
          TextButton(
            key: const Key('pickSolarDateButton'),
            onPressed: onTap,
            child: Text(hasValue ? '修改' : '选择'),
          ),
        ],
      ),
    );
  }
}

class _LunarBirthdayFields extends StatelessWidget {
  const _LunarBirthdayFields({
    required this.hasValue,
    required this.month,
    required this.day,
    required this.isLeapMonth,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.onLeapChanged,
    required this.onClear,
  });

  final bool hasValue;
  final int month;
  final int day;
  final bool isLeapMonth;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<bool> onLeapChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!hasValue)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              '还没有选择农历生日，请选择月份和日期',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('lunarMonthDropdown'),
                initialValue: month,
                decoration: const InputDecoration(labelText: '农历月份'),
                items: <DropdownMenuItem<int>>[
                  for (int i = 1; i <= 12; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(kLunarMonthNames[i - 1]),
                    ),
                ],
                onChanged: (int? value) {
                  if (value != null) onMonthChanged(value);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const Key('lunarDayDropdown'),
                initialValue: day,
                decoration: const InputDecoration(labelText: '农历日期'),
                items: <DropdownMenuItem<int>>[
                  for (int i = 1; i <= 30; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(lunarDayName(i)),
                    ),
                ],
                onChanged: (int? value) {
                  if (value != null) onDayChanged(value);
                },
              ),
            ),
          ],
        ),
        CheckboxListTile(
          key: const Key('lunarLeapCheckbox'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: isLeapMonth,
          onChanged: (bool? value) => onLeapChanged(value ?? false),
          title: const Text(
            '闰月',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onClear, child: const Text('清除生日')),
        ),
      ],
    );
  }
}

class _YearStepper extends StatelessWidget {
  const _YearStepper({required this.year, required this.onChanged});

  final int year;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text(
          '出生年份',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: year > 1900 ? () => onChanged(year - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Text(
          '$year',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        IconButton(
          onPressed: year < 2100 ? () => onChanged(year + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

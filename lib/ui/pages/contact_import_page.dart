import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/birthday_calculator.dart';
import '../../core/contact_text_parser.dart';
import '../../models/birthday.dart';
import '../../models/contact.dart';
import '../../state/contact_controller.dart';
import '../../state/root_tab_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/birthday_facts.dart';
import '../widgets/common.dart';
import '../widgets/contact_text_help.dart';
import '../widgets/forms.dart';

/// 一条解析结果与已有联系人的关系。
enum _DuplicateKind {
  /// 全新的人。
  fresh,

  /// 同名且信息一致 -> 自动合并，不重复添加。
  identical,

  /// 同名但信息不同 -> 仍然新增一条。
  sameNameDifferent,
}

/// 「粘贴文本 -> 批量导入联系人」。
class ContactImportPage extends StatefulWidget {
  const ContactImportPage({super.key, this.initialText = ''});

  /// 预填的文本（从编辑页的「批量导入」跳过来时用）。
  final String initialText;

  @override
  State<ContactImportPage> createState() => _ContactImportPageState();
}

class _ContactImportPageState extends State<ContactImportPage> {
  final TextEditingController _text = TextEditingController();
  List<ParsedContact> _parsed = const <ParsedContact>[];
  bool _importing = false;
  bool _seeded = false;

  /// 逐条的历法选择（用户要求：默认农历，新历自己手动改）。
  /// 只对「文本里没写历法」的那些条目生效。
  final Map<int, BirthdayCalendar> _calendarOf = <int, BirthdayCalendar>{};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    if (widget.initialText.isNotEmpty) {
      _text.text = widget.initialText;
      _reparse(context.read<SettingsController>().settings.importCalendar);
    }
  }

  /// build 里用（需要跟随设置变化重建）。
  BirthdayCalendar get _defaultCalendar =>
      context.watch<SettingsController>().settings.importCalendar;

  /// 回调里用：`context.watch` 只允许在 build 期间调用。
  BirthdayCalendar get _currentCalendar =>
      context.read<SettingsController>().settings.importCalendar;

  void _reparse(BirthdayCalendar calendar) {
    setState(() {
      _parsed = ContactTextParser(defaultCalendar: calendar).parse(_text.text);
      _calendarOf.clear();
    });
  }

  /// 界面和导入都用这一份：把逐条选择应用上去。
  List<ParsedContact> get _effective {
    final List<ParsedContact> result = <ParsedContact>[];
    for (int i = 0; i < _parsed.length; i++) {
      final ParsedContact parsed = _parsed[i];
      final BirthdayCalendar? chosen = _calendarOf[i];
      if (parsed.birthdayCalendarFromText ||
          chosen == null ||
          parsed.birthday == null) {
        result.add(parsed);
      } else {
        result.add(parsed.withCalendar(chosen));
      }
    }
    return result;
  }

  void _setCalendar(int index, BirthdayCalendar calendar) {
    setState(() => _calendarOf[index] = calendar);
  }

  /// 一键把**所有没写历法**的条目改成同一种。
  void _setCalendarForAll(BirthdayCalendar calendar) {
    setState(() {
      for (int i = 0; i < _parsed.length; i++) {
        if (!_parsed[i].birthdayCalendarFromText) _calendarOf[i] = calendar;
      }
    });
  }

  void _onChanged(String value) => _reparse(_currentCalendar);

  List<ParsedContact> get _valid =>
      _effective.where((ParsedContact c) => c.isValid).toList();

  _DuplicateKind _kindOf(ParsedContact parsed, ContactController controller) {
    final Contact probe = parsed.toContact(id: '_probe', now: controller.now);
    if (controller.findIdentical(probe) != null) {
      return _DuplicateKind.identical;
    }
    if (controller.hasSameNameDifferentContent(probe)) {
      return _DuplicateKind.sameNameDifferent;
    }
    return _DuplicateKind.fresh;
  }

  Future<void> _import() async {
    final List<ParsedContact> valid = _valid;
    if (valid.isEmpty) return;
    setState(() => _importing = true);

    final ContactController controller = context.read<ContactController>();
    final DateTime now = controller.now;
    int added = 0;
    int merged = 0;
    int duplicated = 0;

    // 先收集，再**一次性**批量写入：只落盘一次、只重排一次通知。
    // （逐条 addContact 会每次重排全部提醒，11 个人约 500 次插件调用，
    //   既慢又容易在中途出错，导致只进来几条。）
    final List<Contact> toAdd = <Contact>[];
    for (final ParsedContact parsed in valid) {
      final Contact incoming = parsed.toContact(
        id: controller.newContactId(),
        now: now,
        reminder: controller.defaultReminder,
      );
      // 同名 + 信息完全一致 -> 自动合并（跳过，不再新增一条）
      if (controller.findIdentical(incoming) != null) {
        merged++;
        continue;
      }
      if (controller.hasSameNameDifferentContent(incoming)) duplicated++;
      toAdd.add(incoming);
    }
    await controller.addContacts(toAdd);
    added = toAdd.length;
    if (!mounted) return;

    final StringBuffer message = StringBuffer('已导入 $added 位联系人');
    if (merged > 0) message.write('，合并 $merged 位重复的');
    if (duplicated > 0) message.write('，$duplicated 位同名但信息不同');
    showAppSnackBar(context, message.toString());
    // 导入完切到「联系人」页，保证不管从哪个入口进来都能看到刚导入的人
    context.read<RootTabController>().goToContacts();
    Navigator.of(context).pop();
    // 通知权限弹窗放在**导航之后**：不能让系统弹窗把用户卡在这一页
    unawaited(controller.requestNotificationPermission());
  }

  void _fillExample() {
    _text.text = kContactTextExample;
    _reparse(_currentCalendar);
  }

  Future<void> _showFormatHelp() => showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('支持的文本格式'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: ContactTextFormatHelp(onUseExample: _fillExample),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();
    final BirthdayCalendar calendar = _defaultCalendar;
    final List<ParsedContact> items = _effective;
    final List<ParsedContact> valid = _valid;
    final List<_DuplicateKind> kinds = <_DuplicateKind>[
      for (final ParsedContact parsed in items)
        parsed.isValid ? _kindOf(parsed, controller) : _DuplicateKind.fresh,
    ];
    final int mergeCount = kinds
        .where((_DuplicateKind k) => k == _DuplicateKind.identical)
        .length;
    final int newCount = valid.length - mergeCount;
    final int invalidCount = items.length - valid.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('从文本导入'),
        actions: <Widget>[
          IconButton(
            key: const Key('showFormatHelpButton'),
            tooltip: '格式说明',
            onPressed: _showFormatHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          if (_text.text.trim().isNotEmpty)
            IconButton(
              key: const Key('clearImportTextButton'),
              tooltip: '清空',
              onPressed: () {
                _text.clear();
                _reparse(calendar);
              },
              icon: const Icon(Icons.backspace_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
              border: Border.all(color: AppColors.outline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '一行一个字段，写成「字段：值」，冒号中英文都行。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '生日可写 5月20日、1995-05-20、农历八月十五；'
                  '关系可直接写爸爸 / 妈妈 / 爷爷 / 奶奶。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '只有「姓名」是必填的，其它行不写就不填；多位联系人用空行或 --- 隔开。',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ImportCalendarPicker(
            value: calendar,
            onChanged: (BirthdayCalendar value) {
              context.read<SettingsController>().setImportCalendar(value);
              _reparse(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('importTextField'),
            controller: _text,
            minLines: 5,
            maxLines: 12,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '把联系人信息粘贴到这里（支持一次粘贴多位）…',
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              TextButton.icon(
                key: const Key('useExampleButton'),
                onPressed: _fillExample,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: const Text('填入示例'),
              ),
              TextButton.icon(
                key: const Key('inlineHelpButton'),
                onPressed: _showFormatHelp,
                icon: const Icon(Icons.help_outline_rounded, size: 16),
                label: const Text('完整格式说明'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_parsed.isEmpty)
            const EmptyState(
              icon: Icons.content_paste_search_rounded,
              title: '还没有可导入的内容',
              message: '粘贴上面的示例格式，这里会自动识别。',
            )
          else ...<Widget>[
            SectionHeader(
              title: '识别结果',
              subtitle: _summaryText(
                valid: valid.length,
                merge: mergeCount,
                invalid: invalidCount,
              ),
            ),
            // 一键全改：默认农历，新历可以一次性全切过去
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text(
                  '没写历法的按：',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                SelectableChip(
                  key: const Key('bulkCalendar-lunar'),
                  label: '全部农历',
                  dense: true,
                  selected: false,
                  onTap: () => _setCalendarForAll(BirthdayCalendar.lunar),
                ),
                SelectableChip(
                  key: const Key('bulkCalendar-solar'),
                  label: '全部新历',
                  dense: true,
                  selected: false,
                  onTap: () => _setCalendarForAll(BirthdayCalendar.solar),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PreviewCard(
                  parsed: items[i],
                  index: i,
                  kind: kinds[i],
                  calculator: controller.calculator,
                  now: controller.now,
                  defaultCalendar: calendar,
                  fromText: _parsed[i].birthdayCalendarFromText,
                  onCalendar: (BirthdayCalendar value) =>
                      _setCalendar(i, value),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton.icon(
              key: const Key('doImportButton'),
              onPressed: (_importing || newCount == 0) ? null : _import,
              icon: const Icon(Icons.download_done_rounded),
              label: Text(
                newCount == 0
                    ? (mergeCount > 0 ? '都是重复的，无需导入' : '没有可导入的联系人')
                    : '导入 $newCount 位联系人'
                          '${mergeCount > 0 ? '（合并 $mergeCount 位）' : ''}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summaryText({
    required int valid,
    required int merge,
    required int invalid,
  }) {
    final List<String> parts = <String>['$valid 位可导入'];
    if (merge > 0) parts.add('$merge 位重复将合并');
    if (invalid > 0) parts.add('$invalid 条有问题');
    return parts.join('，');
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.parsed,
    required this.index,
    required this.kind,
    required this.calculator,
    required this.now,
    required this.defaultCalendar,
    required this.fromText,
    required this.onCalendar,
  });

  final ParsedContact parsed;
  final int index;
  final _DuplicateKind kind;
  final BirthdayCalculator calculator;
  final DateTime now;

  /// 页面默认历法（逐条按钮里高亮当前选择）。
  final BirthdayCalendar defaultCalendar;

  /// 文本里是否已经写明历法（写了就不给切）。
  final bool fromText;

  final ValueChanged<BirthdayCalendar> onCalendar;

  @override
  Widget build(BuildContext context) {
    final bool ok = parsed.isValid;
    final bool merges = kind == _DuplicateKind.identical;
    return Container(
      key: Key('importPreview-$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(
          color: ok ? AppColors.outline : Theme.of(context).colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18,
                color: ok
                    ? (merges ? AppColors.textSecondary : AppColors.success)
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ok ? parsed.name : '缺少姓名，无法导入',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (ok && kind != _DuplicateKind.fresh)
                _Badge(text: merges ? '重复，自动合并' : '已有同名，将新增', warning: !merges),
            ],
          ),
          if (ok) ...<Widget>[
            const SizedBox(height: 8),
            _line('关系', parsed.relationshipLabelPreview),
            if (parsed.birthday != null) ...<Widget>[
              _line('生日', parsed.birthday!.displayLabel),
              const SizedBox(height: 8),
              if (fromText)
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '文本里写了${parsed.birthday!.calendar.label}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    const Text(
                      '按：',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SelectableChip(
                      key: Key('rowCalendar-lunar-$index'),
                      label: '农历',
                      dense: true,
                      selected:
                          parsed.birthday!.calendar == BirthdayCalendar.lunar,
                      onTap: () => onCalendar(BirthdayCalendar.lunar),
                    ),
                    const SizedBox(width: 6),
                    SelectableChip(
                      key: Key('rowCalendar-solar-$index'),
                      label: '新历',
                      dense: true,
                      selected:
                          parsed.birthday!.calendar == BirthdayCalendar.solar,
                      onTap: () => onCalendar(BirthdayCalendar.solar),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              BirthdayFacts(
                birthday: parsed.birthday!,
                calculator: calculator,
                now: now,
              ),
            ],
            if (parsed.hobbies.isNotEmpty)
              _line('爱好', parsed.hobbies.join('、')),
            if (parsed.tags.isNotEmpty) _line('标签', parsed.tags.join('、')),
            if (parsed.phone != null) _line('手机', parsed.phone!),
            if (parsed.wechat != null) _line('微信/QQ', parsed.wechat!),
            if (parsed.email != null) _line('邮箱', parsed.email!),
            if (parsed.giftIdeas != null) _line('礼物灵感', parsed.giftIdeas!),
            if (parsed.notes != null) _line('备注', parsed.notes!),
          ],
          for (final String warning in parsed.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.warning});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF3E0) : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppSizes.chipRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: warning ? AppColors.warning : AppColors.brandDark,
        ),
      ),
    );
  }
}

extension on ParsedContact {
  /// 预览里用的关系文案。
  String get relationshipLabelPreview {
    final String? relation = relationship?.label;
    final String? custom = relationLabel;
    if (relation == null && custom == null) return '—';
    if (relation == null) return custom!;
    if (custom == null) return relation;
    return '$relation · $custom';
  }
}

import 'package:flutter/material.dart';

import '../../core/contact_text_parser.dart';
import '../../models/birthday.dart';
import '../../theme/app_theme.dart';
import 'forms.dart';

/// 「文本填充」对话框的返回结果。
///
/// - [contact] 不为空：把这一位填进表单。
/// - [batchText] 不为空：文本里有多位联系人，改去「从文本导入」页批量导入。
@immutable
class ContactTextFillResult {
  const ContactTextFillResult.fill(ParsedContact this.contact)
    : batchText = null;

  const ContactTextFillResult.batch(String this.batchText) : contact = null;

  final ParsedContact? contact;
  final String? batchText;
}

/// 文本里没写历法时按哪种历法理解（新历 / 农历）。
class ImportCalendarPicker extends StatelessWidget {
  const ImportCalendarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final BirthdayCalendar value;
  final ValueChanged<BirthdayCalendar> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            '默认历法',
            style: TextStyle(
              fontSize: compact ? 12 : 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SelectableChip(
          key: const Key('importCalendar-lunar'),
          label: '农历',
          dense: true,
          selected: value == BirthdayCalendar.lunar,
          onTap: () => onChanged(BirthdayCalendar.lunar),
        ),
        const SizedBox(width: 8),
        SelectableChip(
          key: const Key('importCalendar-solar'),
          label: '新历',
          dense: true,
          selected: value == BirthdayCalendar.solar,
          onTap: () => onChanged(BirthdayCalendar.solar),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value == BirthdayCalendar.lunar ? '没写历法的按农历算' : '没写历法的按新历算',
            style: TextStyle(
              fontSize: compact ? 11 : 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 格式说明（界面与「文本填充」对话框共用）。
class ContactTextFormatHelp extends StatelessWidget {
  const ContactTextFormatHelp({
    super.key,
    this.onUseExample,
    this.showExample = true,
    this.rules = kContactTextRules,
  });

  /// 点「填入示例」时的回调。
  final VoidCallback? onUseExample;
  final bool showExample;
  final List<String> rules;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.tips_and_updates_outlined,
                size: 17,
                color: AppColors.brand,
              ),
              SizedBox(width: 6),
              Text(
                '支持的格式',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final String rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 6),
                    child: Icon(
                      Icons.circle,
                      size: 4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showExample) ...<Widget>[
            const SizedBox(height: 6),
            const Text(
              '示例（可直接复制修改）',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: const SelectableText(
                kContactTextExample,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onUseExample != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('useExampleButton'),
                  onPressed: onUseExample,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('填入示例'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 「粘贴文本 -> 自动填充」对话框。
///
/// 文本里有**多位**联系人时只填充第一位，并提示改去批量导入。
Future<ContactTextFillResult?> showContactTextFillDialog(
  BuildContext context, {
  BirthdayCalendar defaultCalendar = BirthdayCalendar.lunar,
}) => showDialog<ContactTextFillResult>(
  context: context,
  builder: (BuildContext _) =>
      _ContactTextFillDialog(defaultCalendar: defaultCalendar),
);

class _ContactTextFillDialog extends StatefulWidget {
  const _ContactTextFillDialog({required this.defaultCalendar});

  final BirthdayCalendar defaultCalendar;

  @override
  State<_ContactTextFillDialog> createState() => _ContactTextFillDialogState();
}

class _ContactTextFillDialogState extends State<_ContactTextFillDialog> {
  final TextEditingController _text = TextEditingController();
  late ContactTextParser _parser = ContactTextParser(
    defaultCalendar: widget.defaultCalendar,
  );
  late BirthdayCalendar _calendar = widget.defaultCalendar;
  List<ParsedContact> _all = const <ParsedContact>[];
  bool _showHelp = true;

  ParsedContact? get _first {
    for (final ParsedContact item in _all) {
      if (item.isValid) return item;
    }
    return null;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _reparse() {
    _parser = ContactTextParser(defaultCalendar: _calendar);
    _all = _parser.parse(_text.text);
  }

  void _onChanged(String value) => setState(_reparse);

  @override
  Widget build(BuildContext context) {
    final ParsedContact? first = _first;
    final int count = _all.where((ParsedContact c) => c.isValid).length;

    return AlertDialog(
      title: const Text('从文本自动填充'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_showHelp)
                ContactTextFormatHelp(
                  onUseExample: () {
                    _text.text = kContactTextExample;
                    setState(_reparse);
                  },
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showHelp = true),
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: const Text('查看支持的格式'),
                  ),
                ),
              const SizedBox(height: 10),
              ImportCalendarPicker(
                value: _calendar,
                onChanged: (BirthdayCalendar value) => setState(() {
                  _calendar = value;
                  _reparse();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('fillTextField'),
                controller: _text,
                minLines: 4,
                maxLines: 8,
                autofocus: true,
                decoration: const InputDecoration(hintText: '把联系人信息粘贴到这里…'),
                onChanged: _onChanged,
              ),
              const SizedBox(height: 12),
              if (first == null)
                Text(
                  _text.text.trim().isEmpty ? '至少要有「姓名」。' : '还没识别出「姓名」，请检查格式。',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                )
              else ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        count > 1 ? '识别到 $count 位联系人' : '识别到 1 位联系人',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '将填充：${first.name}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _summary(first),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.brandDark,
                        ),
                      ),
                      if (count > 1) ...<Widget>[
                        const SizedBox(height: 8),
                        const Text(
                          '这个对话框只会填第一位。要一次导入全部，用下面的按钮。',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                      for (final String warning in first.warnings)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '· $warning',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (count > 1) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('fillBatchImportButton'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(ContactTextFillResult.batch(_text.text)),
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: Text('批量导入全部 $count 位'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('applyFillButton'),
          onPressed: first == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop(ContactTextFillResult.fill(first)),
          child: const Text('填充'),
        ),
      ],
    );
  }

  String _summary(ParsedContact parsed) {
    final List<String> parts = <String>[
      if (parsed.relationship != null) parsed.relationship!.label,
      if (parsed.relationLabel != null) parsed.relationLabel!,
      if (parsed.birthday != null) parsed.birthday!.displayLabel,
      if (parsed.hobbies.isNotEmpty) parsed.hobbies.join('/'),
      if (parsed.phone != null) parsed.phone!,
      if (parsed.notes != null) '备注：${parsed.notes}',
    ];
    return parts.isEmpty ? '只填姓名' : parts.join(' · ');
  }
}

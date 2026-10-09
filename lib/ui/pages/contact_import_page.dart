import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/birthday_calculator.dart';
import '../../core/contact_text_parser.dart';
import '../../models/contact.dart';
import '../../state/contact_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/birthday_facts.dart';
import '../widgets/common.dart';
import '../widgets/contact_text_help.dart';

/// 「粘贴文本 -> 批量导入联系人」。
class ContactImportPage extends StatefulWidget {
  const ContactImportPage({super.key});

  @override
  State<ContactImportPage> createState() => _ContactImportPageState();
}

class _ContactImportPageState extends State<ContactImportPage> {
  static const ContactTextParser _parser = ContactTextParser();

  final TextEditingController _text = TextEditingController();
  List<ParsedContact> _parsed = const <ParsedContact>[];
  bool _importing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<ParsedContact> get _valid =>
      _parsed.where((ParsedContact c) => c.isValid).toList();

  void _onChanged(String value) {
    setState(() => _parsed = _parser.parse(value));
  }

  Future<void> _import() async {
    final List<ParsedContact> valid = _valid;
    if (valid.isEmpty) return;
    setState(() => _importing = true);

    final ContactController controller = context.read<ContactController>();
    final DateTime now = controller.now;
    for (final ParsedContact parsed in valid) {
      await controller.addContact(
        parsed.toContact(
          id: controller.newContactId(),
          now: now,
          reminder: controller.defaultReminder,
        ),
      );
    }
    await controller.requestNotificationPermission();
    if (!mounted) return;

    showAppSnackBar(context, '已导入 ${valid.length} 位联系人');
    Navigator.of(context).pop();
  }

  void _fillExample() {
    _text.text = kContactTextExample;
    _onChanged(_text.text);
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
    final List<ParsedContact> valid = _valid;
    final int invalidCount = _parsed.length - valid.length;

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
                _onChanged('');
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
                  '生日可写 5月20日、1995-05-20、农历八月十五；爱好用「、」分隔。',
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
          const SizedBox(height: 18),
          if (_parsed.isEmpty)
            const EmptyState(
              icon: Icons.content_paste_search_rounded,
              title: '还没有可导入的内容',
              message:
                  '粘贴上面的示例格式，右边会自动识别。\n'
                  '只有「姓名」是必填的，其它都可以不写。',
            )
          else ...<Widget>[
            SectionHeader(
              title: '识别结果',
              subtitle: invalidCount > 0
                  ? '${valid.length} 位可导入，$invalidCount 条有问题'
                  : '${valid.length} 位可导入',
            ),
            for (int i = 0; i < _parsed.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PreviewCard(
                  parsed: _parsed[i],
                  index: i,
                  calculator: controller.calculator,
                  now: controller.now,
                  duplicateName:
                      _parsed[i].isValid &&
                      controller.contacts.any(
                        (Contact c) => c.name.trim() == _parsed[i].name.trim(),
                      ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton.icon(
              key: const Key('doImportButton'),
              onPressed: (_importing || valid.isEmpty) ? null : _import,
              icon: const Icon(Icons.download_done_rounded),
              label: Text(
                valid.isEmpty ? '没有可导入的联系人' : '导入 ${valid.length} 位联系人',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.parsed,
    required this.index,
    required this.calculator,
    required this.now,
    required this.duplicateName,
  });

  final ParsedContact parsed;
  final int index;
  final BirthdayCalculator calculator;
  final DateTime now;
  final bool duplicateName;

  @override
  Widget build(BuildContext context) {
    final bool ok = parsed.isValid;
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
                    ? AppColors.success
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
              if (duplicateName)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(AppSizes.chipRadius),
                  ),
                  child: const Text(
                    '已有同名',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
          if (ok) ...<Widget>[
            const SizedBox(height: 8),
            _line('关系', parsed.relationshipLabelPreview),
            if (parsed.birthday != null) ...<Widget>[
              _line('生日', parsed.birthday!.displayLabel),
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

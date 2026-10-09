import 'package:flutter/material.dart';

import '../../core/contact_text_parser.dart';
import '../../theme/app_theme.dart';

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

/// 「粘贴文本 -> 自动填充」对话框：返回解析出来的第一条联系人。
Future<ParsedContact?> showContactTextFillDialog(BuildContext context) =>
    showDialog<ParsedContact>(
      context: context,
      builder: (BuildContext _) => const _ContactTextFillDialog(),
    );

class _ContactTextFillDialog extends StatefulWidget {
  const _ContactTextFillDialog();

  @override
  State<_ContactTextFillDialog> createState() => _ContactTextFillDialogState();
}

class _ContactTextFillDialogState extends State<_ContactTextFillDialog> {
  static const ContactTextParser _parser = ContactTextParser();

  final TextEditingController _text = TextEditingController();
  ParsedContact? _parsed;
  bool _showHelp = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _parsed = _parser.parseFirst(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ParsedContact? parsed = _parsed;
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
                    _onChanged(_text.text);
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
              if (parsed == null)
                Text(
                  _text.text.trim().isEmpty ? '至少要有「姓名」。' : '还没识别出「姓名」，请检查格式。',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                )
              else
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
                        '将填充：${parsed.name}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _summary(parsed),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.brandDark,
                        ),
                      ),
                      for (final String warning in parsed.warnings)
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
          onPressed: parsed == null
              ? null
              : () => Navigator.of(context).pop(parsed),
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

import 'package:flutter/material.dart';

import 'pages/contact_detail_page.dart';
import 'pages/contact_edit_page.dart';

/// 打开联系人详情页。
Future<void> openContactDetail(BuildContext context, String contactId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ContactDetailPage(contactId: contactId),
      ),
    );

/// 打开联系人编辑页；[contactId] 为空表示新建。
Future<void> openContactEditor(BuildContext context, {String? contactId}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => ContactEditPage(contactId: contactId),
      ),
    );

/// 通用确认弹窗，返回用户是否点了确认。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 统一的轻提示。
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

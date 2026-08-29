import 'package:flutter/material.dart';
import 'thome_auth_client.dart';

/// 公告弹窗框架
/// 用法：AnnouncementDialog.show(context, announcements)
class AnnouncementDialog {
  AnnouncementDialog._();

  /// 显示公告列表（弹窗框架，可连续展示多条）
  static Future<void> show(
      BuildContext context, List<ThomeAnnouncement> announcements) async {
    if (announcements.isEmpty) return;

    // 按优先级排序（高优先级在前）
    final sorted = List<ThomeAnnouncement>.from(announcements)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final ann in sorted) {
      if (!context.mounted) return;
      final shouldShow = _isVisible(ann);
      if (!shouldShow) continue;

      await showDialog(
        context: context,
        barrierDismissible: !_isForcedType(ann.type),
        builder: (ctx) => _AnnouncementDialogContent(announcement: ann),
      );
    }
  }

  /// 判断公告当前是否在展示期内
  static bool _isVisible(ThomeAnnouncement ann) {
    final now = DateTime.now();
    if (ann.startTime != null && ann.startTime!.isNotEmpty) {
      final start = DateTime.tryParse(ann.startTime!);
      if (start != null && now.isBefore(start)) return false;
    }
    if (ann.endTime != null && ann.endTime!.isNotEmpty) {
      final end = DateTime.tryParse(ann.endTime!);
      if (end != null && now.isAfter(end)) return false;
    }
    return true;
  }

  /// 公告类型是否为强制展示（不可点击外部关闭，必须点确认）
  static bool _isForcedType(String type) {
    return type == 'warning' || type == 'notice' || type == 'update';
  }
}

class _AnnouncementDialogContent extends StatelessWidget {
  final ThomeAnnouncement announcement;

  const _AnnouncementDialogContent({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconFor(announcement.type);
    final color = _colorFor(announcement.type, theme);

    return PopScope(
      canPop: announcement.type != 'warning' && announcement.type != 'notice' && announcement.type != 'update',
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                announcement.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            announcement.content,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'warning':
      case 'notice':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'update':
        return Icons.system_update_alt_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _colorFor(String type, ThemeData theme) {
    switch (type) {
      case 'warning':
      case 'notice':
        return Colors.orange;
      case 'error':
        return theme.colorScheme.error;
      case 'success':
        return Colors.green;
      case 'update':
        return Colors.blue;
      default:
        return theme.colorScheme.primary;
    }
  }
}
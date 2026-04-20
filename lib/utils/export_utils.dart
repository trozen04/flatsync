import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_info.dart';
import 'date_utils.dart';

class ExportUtils {
  static String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

  static String buildCsv(List<dynamic> items) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Description,Amount (Rs),Direction');
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final type = (item['type'] as String?) ?? '';
      final description = (item['description'] as String?) ?? '';
      final amountPaise = (item['amount'] as num?)?.round() ?? 0;
      final amount = (amountPaise / 100).toStringAsFixed(2);
      final direction = (item['direction'] as String?) ?? '';
      final createdAt = item['createdAt'];
      final date = createdAt is DateTime
          ? AppDateUtils.formatDateTime(createdAt)
          : createdAt?.toString() ?? '';
      buffer.writeln(
        '${_escapeCsv(date)},${_escapeCsv(type)},${_escapeCsv(description)},${_escapeCsv(amount)},${_escapeCsv(direction)}',
      );
    }
    return buffer.toString();
  }

  static Future<void> exportAndShare(List<dynamic> items) async {
    try {
      final csv = buildCsv(items);
      final dir = await getTemporaryDirectory();
      final fileName = 'settleflow_history_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'SettleFlow History Export',
        text: AppInfo.inviteMessage,
      );
    } catch (e) {
      developer.log('Export error: $e');
      rethrow;
    }
  }
}

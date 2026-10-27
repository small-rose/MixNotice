/// 匿名埋点（FR-28 / E-07）
/// V1.0：本地环形缓存（最多 20 条），上报端点未就绪时静默失败、下次补报；
/// 禁止采集任何个人身份信息；上报失败不得阻塞任何功能。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  static const int _maxQueue = 20; // E-07 最多缓存 20 条
  static const String _endpoint =
      'https://analytics.invalid.local/v1/event'; // TODO(V1.0 W8): 服务端联调替换

  final List<Map<String, dynamic>> _queue = [];
  bool _flushing = false;

  void log(String event, Map<String, dynamic> props) {
    if (_queue.length >= _maxQueue) _queue.removeAt(0); // 静默丢弃最旧
    _queue.add({'event': event, 'props': props, 'ts': DateTime.now().toIso8601String()});
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      final req = await client.postUrl(Uri.parse(_endpoint)).timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw const SocketException('timeout'),
          );
      req.headers.contentType = ContentType.json;
      req.write(json.encode({'events': List.of(_queue)}));
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 300) _queue.clear();
      client.close(force: true);
    } catch (_) {
      // E-07：静默失败，保留缓存下次补报
    } finally {
      _flushing = false;
    }
  }
}

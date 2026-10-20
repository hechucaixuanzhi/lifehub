// API 地址通过 dart-define 注入
//
// 本地开发:
// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
//
// 家庭服务器:
// flutter build apk \
// --dart-define=API_BASE_URL=https://your-tunnel-domain
//
// 不要把生产地址硬编码
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String baseUrl = defaultBaseUrl;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('server_base_url') ?? defaultBaseUrl;
  }

  static String normalizeUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                (uri.host == '127.0.0.1' || uri.host == 'localhost')))) {
      throw const FormatException('请输入 HTTPS 服务器地址，例如 https://example.com');
    }
    return uri.replace(path: '').toString();
  }

  static Future<void> saveBaseUrl(String url) async {
    final normalized = normalizeUrl(url);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('server_base_url', normalized)) {
      throw StateError('服务器地址保存失败，请重试');
    }
    baseUrl = normalized;
  }

  /// 与后端 SKIP_AUTH=true 对应的客户端开关（仅本地联调，生产必须为 false）。
  static const bool skipAuth = bool.fromEnvironment(
    'SKIP_AUTH',
    defaultValue: false,
  );
}

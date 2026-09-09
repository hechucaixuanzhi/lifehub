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
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// 与后端 SKIP_AUTH=true 对应的客户端开关（仅本地联调，生产必须为 false）。
  static const bool skipAuth = bool.fromEnvironment(
    'SKIP_AUTH',
    defaultValue: false,
  );
}

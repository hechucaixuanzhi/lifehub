import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifehub/core/network/api_config.dart';

void main() {
  setUp(() { SharedPreferences.setMockInitialValues({}); });

  test('normalizes and persists HTTPS server across initialization', () async {
    await ApiConfig.saveBaseUrl(' https://example.com/ ');
    ApiConfig.baseUrl = ApiConfig.defaultBaseUrl;
    await ApiConfig.initialize();
    expect(ApiConfig.baseUrl, 'https://example.com');
  });

  test('rejects unsafe or malformed server URLs without changing configuration', () async {
    await ApiConfig.saveBaseUrl('https://example.com');
    for (final input in ['http://example.com', 'https://user:pass@example.com',
      'https://example.com/path', 'https://example.com?key=x', 'invalid']) {
      expect(() => ApiConfig.normalizeUrl(input), throwsFormatException);
    }
    expect(ApiConfig.baseUrl, 'https://example.com');
    expect(ApiConfig.normalizeUrl('http://127.0.0.1:8000/'), 'http://127.0.0.1:8000');
  });
}

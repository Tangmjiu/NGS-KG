import 'package:flutter_test/flutter_test.dart';
import 'package:ngskg_plus/services/auth_service.dart';

void main() {
  group('AuthService QR response normalization', () {
    test('normalizes current key response fields', () {
      final result = AuthService.normalizeQrKeyData({
        'qrcode': 'current-key',
        'qrcode_img': 'data:image/png;base64,current-image',
      });

      expect(result['key'], 'current-key');
      expect(result['qrimg'], 'data:image/png;base64,current-image');
    });

    test('keeps legacy key response fields', () {
      final result = AuthService.normalizeQrKeyData({
        'key': 'legacy-key',
        'qrimg': 'legacy-image',
      });

      expect(result['key'], 'legacy-key');
      expect(result['qrimg'], 'legacy-image');
    });

    test('rejects key response without a credential', () {
      expect(
        () => AuthService.normalizeQrKeyData({'qrcode_img': 'image'}),
        throwsFormatException,
      );
    });

    test('normalizes create response base64 field', () {
      final result = AuthService.normalizeQrImageData({
        'url': 'https://example.com/qr',
        'base64': 'data:image/png;base64,created-image',
      });

      expect(result['qrimg'], 'data:image/png;base64,created-image');
      expect(result['url'], 'https://example.com/qr');
    });
  });

  group('AuthService QR status parsing', () {
    test('parses waiting, confirmation and expired statuses', () {
      expect(AuthService.parseQrResponse({'data': 0}).$1, 0);
      expect(AuthService.parseQrResponse({'data': 1}).$1, 1);
      expect(AuthService.parseQrResponse({'data': 2}).$1, 2);
      expect(AuthService.parseQrResponse({'data': '2'}).$1, 2);
    });

    test('parses successful login user', () {
      final (status, user) = AuthService.parseQrResponse({
        'data': {
          'status': 4,
          'token': 'token-value',
          'userid': 12345,
          'nickname': 'QR User',
          'avatar': 'https://example.com/avatar.jpg',
          'vip_type': 6,
          'is_vip': 1,
        },
      });

      expect(status, 4);
      expect(user?.userId, 12345);
      expect(user?.token, 'token-value');
      expect(user?.nickname, 'QR User');
      expect(user?.avatarUrl, 'https://example.com/avatar.jpg');
    });
  });
}

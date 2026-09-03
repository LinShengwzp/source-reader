import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 允许 Source Tester 发起网络请求并访问 cleartext HTTP', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
    expect(manifest, contains('android:usesCleartextTraffic="true"'));
  });

  test('iOS 与 macOS Info.plist 允许 Source Tester 访问 HTTP 书源', () {
    final atsPolicy = RegExp(
      r'<key>NSAppTransportSecurity</key>\s*'
      r'<dict>\s*'
      r'<key>NSAllowsArbitraryLoads</key>\s*'
      r'<true/>\s*'
      r'</dict>',
    );

    for (final path in <String>[
      'ios/Runner/Info.plist',
      'macos/Runner/Info.plist',
    ]) {
      expect(_read(path), matches(atsPolicy), reason: path);
    }
  });

  test('macOS Debug 与 Release entitlement 都允许客户端网络访问', () {
    final clientEntitlement = RegExp(
      r'<key>com\.apple\.security\.network\.client</key>\s*<true/>',
    );

    for (final path in <String>[
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      expect(_read(path), matches(clientEntitlement), reason: path);
    }

    expect(
      _read('macos/Runner/DebugProfile.entitlements'),
      contains('<key>com.apple.security.network.server</key>'),
    );
  });
}

String _read(String path) => File(path).readAsStringSync();

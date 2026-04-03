import 'package:aegis_app/providers/profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('password update validates and updates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(profileProvider.notifier);

    final fail = await notifier.updatePassword(
      currentPassword: 'oldpass123',
      newPassword: 'newpass123',
      confirmPassword: 'mismatch123',
    );
    expect(fail, isNotNull);

    final ok = await notifier.updatePassword(
      currentPassword: 'oldpass123',
      newPassword: 'newpass123',
      confirmPassword: 'newpass123',
    );
    expect(ok, isNull);
  });

  test('2FA setup requires authenticated session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(profileProvider.notifier);
    final code = await notifier.start2FASetup();
    expect(code, isNull);

    final bad = await notifier.verify2FA('111111');
    expect(bad, isFalse);
    expect(container.read(profileProvider).is2FAEnabled, isFalse);
  });
}

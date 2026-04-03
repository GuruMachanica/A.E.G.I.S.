import 'package:aegis_app/models/call_record.dart';
import 'package:aegis_app/providers/history_provider.dart';
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

  test('defaults to last 7 days records', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(historyProvider);
    final records = state.filteredRecords;

    expect(state.filterPeriod, FilterPeriod.sevenDays);
    expect(records.any((r) => r.id == '6'), isFalse); // 8 days old
  });

  test('search filters by caller name', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(historyProvider.notifier).setSearch('mom');
    final records = container.read(historyProvider).filteredRecords;

    expect(records.length, 1);
    expect(records.first.callerName.toLowerCase(), contains('mom'));
  });

  test('add record persists to state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(historyProvider).records.length;
    await container.read(historyProvider.notifier).addRecord(
          CallRecord(
            id: 't-1',
            callerName: 'Test Caller',
            phoneNumber: '+10000000000',
            callTime: DateTime.now(),
            riskLevel: CallRecord.levelFromScore(75),
            riskScore: 75,
            syntheticScore: 70,
            intentScore: 80,
          ),
        );

    final after = container.read(historyProvider).records.length;
    expect(after, before + 1);
  });
}

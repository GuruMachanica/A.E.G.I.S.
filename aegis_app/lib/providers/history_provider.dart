import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_record.dart';
import '../services/backend_service.dart';
import '../services/local_database_service.dart';
import 'auth_provider.dart';

enum FilterPeriod { today, sevenDays }

class HistoryState {
  final List<CallRecord> records;
  final String searchQuery;
  final FilterPeriod filterPeriod;
  final bool isSyncing;
  final String? syncError;

  const HistoryState({
    this.records = const [],
    this.searchQuery = '',
    this.filterPeriod = FilterPeriod.sevenDays,
    this.isSyncing = false,
    this.syncError,
  });

  HistoryState copyWith({
    List<CallRecord>? records,
    String? searchQuery,
    FilterPeriod? filterPeriod,
    bool? isSyncing,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return HistoryState(
      records: records ?? this.records,
      searchQuery: searchQuery ?? this.searchQuery,
      filterPeriod: filterPeriod ?? this.filterPeriod,
      isSyncing: isSyncing ?? this.isSyncing,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
    );
  }

  List<CallRecord> get filteredRecords {
    final now = DateTime.now();
    final cutoff = switch (filterPeriod) {
      FilterPeriod.today => DateTime(now.year, now.month, now.day),
      FilterPeriod.sevenDays => now.subtract(const Duration(days: 7)),
    };

    return records.where((r) {
      final afterCutoff = !r.callTime.isBefore(cutoff);
      if (!afterCutoff) return false;
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return r.callerName.toLowerCase().contains(q) ||
          r.phoneNumber.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.callTime.compareTo(a.callTime));
  }

  int get recentActivityCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return records.where((r) => !r.callTime.isBefore(cutoff)).length;
  }

  int get todayScanned {
    final today = DateTime.now();
    return records
        .where(
          (r) =>
              r.callTime.year == today.year &&
              r.callTime.month == today.month &&
              r.callTime.day == today.day,
        )
        .length;
  }

  int get suspiciousCalls =>
      records.where((r) => r.riskScore >= 35 && r.riskScore < 65).length;

  int get blockedThreatsToday {
    final today = DateTime.now();
    return records
        .where(
          (r) =>
              r.callTime.year == today.year &&
              r.callTime.month == today.month &&
              r.callTime.day == today.day &&
              r.riskScore >= 65,
        )
        .length;
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    Future.microtask(_hydrate);
    return const HistoryState();
  }

  Future<void> _hydrate() async {
    final local = await ref.read(localDatabaseProvider).loadCallRecords();
    if (!ref.mounted) return;
    state = state.copyWith(records: local);
    await _fetchRemote();
  }

  Future<void> _replaceLocalCache(List<CallRecord> records) async {
    final localDb = ref.read(localDatabaseProvider);
    await localDb.clearCallRecords();
    for (final record in records) {
      await localDb.insertCallRecord(record);
    }
  }

  Future<void> _fetchRemote() async {
    await ref.read(authProvider.notifier).ensureSessionValid();
    final auth = ref.read(authProvider);
    final token = auth.accessToken;
    if (token.isEmpty) return;

    try {
      final remote = await ref
          .read(backendServiceProvider)
          .fetchHistory(token: token);
      if (!ref.mounted) return;

      if (remote.isNotEmpty) {
        await _replaceLocalCache(remote);
        if (!ref.mounted) return;
        state = state.copyWith(records: remote, clearSyncError: true);
        return;
      }

      if (state.records.isNotEmpty) {
        await ref
            .read(backendServiceProvider)
            .syncHistory(token: token, records: state.records);
      }
      if (!ref.mounted) return;
      state = state.copyWith(clearSyncError: true);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(syncError: e.toString());
    }
  }

  Future<void> _sync() async {
    await ref.read(authProvider.notifier).ensureSessionValid();
    final token = ref.read(authProvider).accessToken;
    if (token.isEmpty) return;

    state = state.copyWith(isSyncing: true, clearSyncError: true);
    try {
      await ref
          .read(backendServiceProvider)
          .syncHistory(token: token, records: state.records);
      if (!ref.mounted) return;
      state = state.copyWith(isSyncing: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isSyncing: false, syncError: e.toString());
    }
  }

  Future<void> setSearch(String q) async {
    state = state.copyWith(searchQuery: q);
  }

  Future<void> setFilter(FilterPeriod p) async {
    state = state.copyWith(filterPeriod: p);
  }

  Future<void> addRecord(CallRecord r) async {
    await ref.read(localDatabaseProvider).insertCallRecord(r);
    state = state.copyWith(records: [r, ...state.records]);
    await _sync();
  }

  Future<void> clearAll() async {
    await ref.read(localDatabaseProvider).clearCallRecords();
    state = state.copyWith(records: []);
    await ref.read(authProvider.notifier).ensureSessionValid();
    final auth = ref.read(authProvider);
    if (auth.accessToken.isEmpty) return;
    try {
      await ref
          .read(backendServiceProvider)
          .clearHistory(token: auth.accessToken);
      if (!ref.mounted) return;
      state = state.copyWith(clearSyncError: true);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(syncError: e.toString());
    }
  }

  void clearSyncError() => state = state.copyWith(clearSyncError: true);
}

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);

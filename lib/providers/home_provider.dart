import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_record.dart';

class HomeState {
  final bool detectionEnabled;
  final CallRecord? lastThreat;

  const HomeState({this.detectionEnabled = false, this.lastThreat});

  HomeState copyWith({
    bool? detectionEnabled,
    CallRecord? lastThreat,
    bool clearThreat = false,
  }) {
    return HomeState(
      detectionEnabled: detectionEnabled ?? this.detectionEnabled,
      lastThreat: clearThreat ? null : (lastThreat ?? this.lastThreat),
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  static const _homeKey = 'aegis_home_state';

  @override
  HomeState build() {
    Future.microtask(_hydrate);
    return const HomeState();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homeKey);
    if (raw == null || raw.isEmpty) return;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final threat = json['lastThreat'] == null
        ? null
        : CallRecord.fromJson(json['lastThreat'] as Map<String, dynamic>);

    state = state.copyWith(
      detectionEnabled: json['detectionEnabled'] as bool? ?? false,
      lastThreat: threat,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _homeKey,
      jsonEncode({
        'detectionEnabled': state.detectionEnabled,
        'lastThreat': state.lastThreat?.toJson(),
      }),
    );
  }

  Future<void> toggleDetection() async {
    state = state.copyWith(detectionEnabled: !state.detectionEnabled);
    await _persist();
  }

  Future<void> reportThreat(CallRecord record) async {
    state = state.copyWith(lastThreat: record);
    await _persist();
  }

  Future<void> clearThreat() async {
    state = state.copyWith(clearThreat: true);
    await _persist();
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

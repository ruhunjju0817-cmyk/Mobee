import '../models/alarm.dart';

/// 언제 경보를 울릴지 정하는 규칙 (플랫폼 의존 없음, 테스트 용이).
///
/// - 상태가 **나빠지는 순간**에만 울린다 (같거나 좋아지면 울리지 않음).
/// - 같은 단계는 [cooldown](기본 5초) 안에 다시 울리지 않는다.
///   예: Danger → Normal → Danger가 5초 안에 일어나면 두 번째는 조용히.
/// - 더 나쁜 단계로 바뀌면 바로 울린다. 쿨다운은 **단계별**이라
///   Warning이 방금 울렸어도 Danger는 즉시 울린다.
class AlarmPolicy {
  AlarmPolicy({this.cooldown = const Duration(seconds: 5)});

  final Duration cooldown;

  AlarmStage _current = AlarmStage.none;
  final _lastFired = <AlarmStage, DateTime>{};

  AlarmStage get current => _current;

  /// 새 단계를 반영하고, 울려야 하면 true.
  bool update(AlarmStage stage, DateTime now) {
    final previous = _current;
    _current = stage;
    if (!stage.isWorseThan(previous)) return false;

    final last = _lastFired[stage];
    if (last != null && now.difference(last) < cooldown) return false;

    _lastFired[stage] = now;
    return true;
  }
}

import 'package:flutter/material.dart';

import '../models/agv_enums.dart';
import '../models/sensor_data.dart';
import 'app_theme.dart';

extension DriveStateStyle on DriveState {
  Color get color => switch (this) {
    DriveState.normal => AppColors.safe,
    DriveState.warning => AppColors.warning,
    DriveState.danger => AppColors.alert,
    DriveState.blocked => AppColors.danger,
    DriveState.stopped => AppColors.inactive,
  };

  IconData get icon => switch (this) {
    DriveState.normal => Icons.check_circle_rounded,
    DriveState.warning => Icons.warning_amber_rounded,
    DriveState.danger => Icons.dangerous_rounded,
    DriveState.blocked => Icons.block_rounded,
    DriveState.stopped => Icons.pause_circle_filled_rounded,
  };
}

extension AgvZoneStyle on AgvZone {
  Color color(AppPalette p) =>
      this == AgvZone.unknown ? AppColors.inactive : p.accent;
}

extension HazardTypeStyle on HazardType {
  IconData get icon => switch (this) {
    HazardType.frontObstacle => Icons.arrow_circle_up_rounded,
    HazardType.sideBlindSpot => Icons.visibility_off_rounded,
    HazardType.collision => Icons.car_crash_rounded,
    HazardType.tilt => Icons.rotate_right_rounded,
  };

  /// 활성화된 위험 요소의 색상.
  /// 충돌은 항상 빨강, 나머지는 전체 주행 상태 색을 따른다
  /// (Warning 노랑, Danger 주황, Blocked 빨강). Normal/Stopped 중 감지 시 주황.
  Color activeColor(DriveState state) {
    if (this == HazardType.collision) return AppColors.danger;
    return switch (state) {
      DriveState.warning ||
      DriveState.danger ||
      DriveState.blocked => state.color,
      DriveState.normal || DriveState.stopped => AppColors.alert,
    };
  }
}

extension SensorLevelStyle on SensorLevel {
  Color get color => switch (this) {
    SensorLevel.safe => AppColors.safe,
    SensorLevel.caution => AppColors.warning,
    SensorLevel.critical => AppColors.danger,
  };
}

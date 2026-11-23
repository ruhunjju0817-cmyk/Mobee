import 'package:flutter/material.dart';

import '../controllers/monitor_controller.dart';
import '../services/agv_data_source.dart';
import '../services/bluetooth_agv_data_source.dart';
import '../theme/app_theme.dart';

enum _SourceMode { dummy, bluetooth }

/// 데이터 소스(더미/블루투스) 선택과 블루투스 기기 연결을 관리하는 바텀 시트.
Future<void> showConnectionSheet(
  BuildContext context,
  MonitorController controller,
) {
  final p = context.palette;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: p.surface,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => ConnectionSheet(controller: controller),
  );
}

class ConnectionSheet extends StatefulWidget {
  const ConnectionSheet({super.key, required this.controller});

  final MonitorController controller;

  @override
  State<ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<ConnectionSheet> {
  MonitorController get _c => widget.controller;

  late _SourceMode _mode = _c.isBluetooth
      ? _SourceMode.bluetooth
      : _SourceMode.dummy;
  Future<List<PairedDevice>>? _devices;

  @override
  void initState() {
    super.initState();
    if (_mode == _SourceMode.bluetooth) _loadDevices();
  }

  void _loadDevices() {
    final devices = _c.loadPairedDevices();
    setState(() {
      _devices = devices;
    });
  }

  void _selectMode(_SourceMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    if (mode == _SourceMode.dummy) {
      _c.useDummy();
    } else {
      // 블루투스 탭은 목록만 보여주고, 기기를 눌러야 실제로 전환된다.
      _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final p = context.palette;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '데이터 연결',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentSummary(),
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_SourceMode>(
                key: const ValueKey('source-mode'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _SourceMode.dummy,
                    icon: Icon(Icons.science_outlined),
                    label: Text('더미'),
                  ),
                  ButtonSegment(
                    value: _SourceMode.bluetooth,
                    icon: Icon(Icons.bluetooth),
                    label: Text('블루투스'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _selectMode(s.first),
              ),
              const SizedBox(height: 16),
              if (_mode == _SourceMode.dummy)
                _Hint(
                  icon: Icons.info_outline,
                  text:
                      'AGV 없이 시뮬레이션 데이터를 표시합니다. '
                      '하단 버튼으로 주행 상태를 바꿔 볼 수 있습니다.',
                )
              else
                _buildDeviceList(context),
              if (_c.errorMessage != null) ...[
                const SizedBox(height: 12),
                _Hint(
                  icon: Icons.error_outline,
                  text: _c.errorMessage!,
                  color: AppColors.danger,
                ),
              ],
              const SizedBox(height: 16),
              _buildActionButton(),
            ],
          ),
        );
      },
    );
  }

  String _currentSummary() {
    final state = _c.connection.label;
    final device = _c.bluetoothDeviceName;
    return device == null ? '현재: 더미 데이터 · $state' : '현재: $device · $state';
  }

  Widget _buildDeviceList(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('페어링된 기기', style: AppText.label(p))),
            IconButton(
              key: const ValueKey('refresh-devices'),
              tooltip: '목록 새로고침',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadDevices,
            ),
          ],
        ),
        FutureBuilder<List<PairedDevice>>(
          future: _devices,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return _Hint(
                icon: Icons.bluetooth_disabled,
                text: '${snap.error}',
                color: AppColors.danger,
              );
            }
            final devices = snap.data ?? const [];
            if (devices.isEmpty) {
              return const _Hint(
                icon: Icons.bluetooth_searching,
                text:
                    '페어링된 기기가 없습니다.\n'
                    '휴대폰 설정 > 블루투스에서 AGV 모듈(HC-05/06)을 먼저 '
                    '페어링한 뒤 새로고침하세요. (기본 PIN: 1234 또는 0000)',
              );
            }
            return Column(
              children: [for (final d in devices) _deviceTile(context, d)],
            );
          },
        ),
      ],
    );
  }

  Widget _deviceTile(BuildContext context, PairedDevice d) {
    final p = context.palette;
    final isCurrent = d.name == _c.bluetoothDeviceName;
    final isLast = d.name == _c.lastDeviceName;

    final Widget? trailing = isCurrent
        ? switch (_c.connection) {
            ConnectionStatus.connecting => const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            ConnectionStatus.connected => const Icon(
              Icons.check_circle,
              color: AppColors.safe,
            ),
            ConnectionStatus.error => const Icon(
              Icons.error,
              color: AppColors.danger,
            ),
            ConnectionStatus.disconnected => Icon(
              Icons.link_off,
              color: p.textMuted,
            ),
          }
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrent ? p.accent.withValues(alpha: 0.10) : p.surfaceHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent ? p.accent.withValues(alpha: 0.6) : p.border,
        ),
      ),
      child: ListTile(
        key: ValueKey('device-${d.address}'),
        leading: Icon(
          Icons.bluetooth,
          color: isCurrent ? p.accent : p.textSecondary,
        ),
        title: Text(
          d.name,
          style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
        ),
        subtitle: Text(
          isLast ? '${d.address} · 최근 연결' : d.address,
          style: TextStyle(fontSize: 12, color: p.textMuted),
        ),
        trailing: trailing,
        onTap: isCurrent && _c.connection == ConnectionStatus.connected
            ? null
            : () => _c.connectBluetooth(d.name),
      ),
    );
  }

  /// 현재 소스 기준 연결 / 연결 해제 버튼.
  Widget _buildActionButton() {
    final busy =
        _c.connection == ConnectionStatus.connected ||
        _c.connection == ConnectionStatus.connecting;

    // 블루투스 탭인데 아직 기기를 고르지 않음 (소스는 여전히 더미).
    if (_mode == _SourceMode.bluetooth && !_c.isBluetooth) {
      return const FilledButton(
        key: ValueKey('connect-button'),
        onPressed: null,
        child: Text('위 목록에서 기기를 선택하세요'),
      );
    }
    if (busy) {
      return OutlinedButton.icon(
        key: const ValueKey('disconnect-button'),
        onPressed: _c.stop,
        icon: const Icon(Icons.link_off),
        label: const Text('연결 해제'),
      );
    }
    return FilledButton.icon(
      key: const ValueKey('connect-button'),
      onPressed: _c.start,
      icon: const Icon(Icons.link),
      label: Text(_c.isBluetooth ? '${_c.bluetoothDeviceName}에 연결' : '연결'),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.textSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: c)),
          ),
        ],
      ),
    );
  }
}

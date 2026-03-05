import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

import '../../../attendance/domain/usecases/mark_attendance_usecase.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../attendance/presentation/bloc/attendance_event.dart';
import '../../../attendance/presentation/bloc/attendance_state.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../user/domain/repository/user_repository.dart';
import '../../../branch/domain/repository/branch_repository.dart';
import '../../../branch/domain/entities/branch_entity.dart';
import '../../../attendance/domain/repository/attendance_repository.dart';
import '../../../../core/network/token_manager.dart';
import '../../../auth/domain/usecases/login_usecase.dart';
import '../../../auth/domain/usecases/logout_usecase.dart';
import '../../../auth/domain/usecases/refresh_token_usecase.dart';
import '../../../auth/domain/repository/auth_repository.dart';
import '../../../attendance/domain/usecases/list_attendance_usecase.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';

// Top-level Branch selector overlay used as a dialog content
class BranchSelectorOverlay extends StatefulWidget {
  final BranchRepository repository;
  final TokenManager tokenManager;
  const BranchSelectorOverlay({Key? key, required this.repository, required this.tokenManager}) : super(key: key);

  @override
  State<BranchSelectorOverlay> createState() => _BranchSelectorOverlayState();
}

class _BranchSelectorOverlayState extends State<BranchSelectorOverlay> {
  List<BranchEntity> _branches = [];
  bool _loading = true;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.listBranches();
      final saved = await widget.tokenManager.readSelectedBranchId();
      if (!mounted) return;
      setState(() {
        _branches = list;
        _selectedId = saved ?? (list.isNotEmpty ? list.first.id : null);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load branches: $e')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveSelection() async {
    if (_selectedId == null) return;
    await widget.tokenManager.saveSelectedBranchId(_selectedId!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch selected')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Select Branch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: _saveSelection, child: const Text('Save'))
          ]),
          const SizedBox(height: 8),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: _branches.length,
                    itemBuilder: (ctx, idx) {
                      final b = _branches[idx];
                      return ListTile(
                        leading: b.consultancyLogo != null && b.consultancyLogo!.isNotEmpty ? SizedBox(width: 48, height: 48, child: Image.network(b.consultancyLogo!, fit: BoxFit.cover)) : null,
                        title: Text(b.consultancyName),
                        subtitle: Text(b.consultancyDesc),
                        trailing: _selectedId == b.id ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () => setState(() => _selectedId = b.id),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

Future<bool?> showBranchSelectorOverlay(BuildContext context) async {
  final branchRepo = RepositoryProvider.of<BranchRepository>(context);
  final tokenManager = RepositoryProvider.of<TokenManager>(context);

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Select Branch',
    barrierColor: Color.fromRGBO(0,0,0,0.4),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.92,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: BranchSelectorOverlay(repository: branchRepo, tokenManager: tokenManager),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut), child: child),
  );

  return result;
}

// Embedded Attendance widget: adapted from AttendancePage but without its own Scaffold so it can be placed in dashboard.
class EmbeddedAttendance extends StatefulWidget {
  const EmbeddedAttendance({Key? key}) : super(key: key);
  @override
  State<EmbeddedAttendance> createState() => _EmbeddedAttendanceState();
}

class _EmbeddedAttendanceState extends State<EmbeddedAttendance> {
  bool _isLoadingDialogVisible = false;

  void _showLoadingDialog(BuildContext context) {
    if (_isLoadingDialogVisible) return;
    _isLoadingDialogVisible = true;
    showDialog<void>(context: context, barrierDismissible: false, useRootNavigator: true, builder: (ctx) => const Center(child: CircularProgressIndicator())).catchError((_) {});
  }

  void _hideLoadingDialog(BuildContext context) {
    if (!_isLoadingDialogVisible) return;
    _isLoadingDialogVisible = false;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }

  Future<Position?> _determinePosition(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final open = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Location services disabled'), content: const Text('Please enable location services to mark attendance.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open settings'))]));
      if (open == true) await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (e) {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Location permissions not configured'), content: const Text('No location permissions are defined in the Android manifest. Please ensure ACCESS_FINE_LOCATION or ACCESS_COARSE_LOCATION is added.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
      return null;
    }

    if (permission == LocationPermission.denied) {
      final ask = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Location permission required'), content: const Text('This app needs location permission to mark your attendance.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Allow'))]));
      if (ask != true) return null;
      try {
        permission = await Geolocator.requestPermission();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to request location permission')));
        return null;
      }
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      final open = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Permission permanently denied'), content: const Text('Location permission is permanently denied. Please open app settings to grant permission.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open settings'))]));
      if (open == true) await Geolocator.openAppSettings();
      return null;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      return null;
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '--:--:--';
    try {
      final local = dt.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt.toLocal().toString();
    }
  }

  String _formatDateHeader(DateTime dt) {
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${weekdays[dt.weekday % 7]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final s = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listener: (context, state) {
        if (state is AttendanceLoading) _showLoadingDialog(context);
        else if (state is AttendanceLoaded || state is AttendanceError) _hideLoadingDialog(context);

        if (state is AttendanceActionInProgress) _hideLoadingDialog(context);
        if (state is AttendanceActionSuccess) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message ?? 'Attendance recorded')));
        if (state is AttendanceActionFailure) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${state.message}')));
      },
      builder: (context, state) {
        if (state is AttendanceLoading || state is AttendanceInitial) return const Center(child: CircularProgressIndicator());
        if (state is AttendanceError) return Center(child: Text('Error: ${state.message}'));

        final List<AttendanceRecord> records = state is AttendanceLoaded ? state.records : <AttendanceRecord>[];
        final DateTime now = state is AttendanceLoaded ? state.now : DateTime.now();
        final AttendanceRecord? todayRecord = records.isNotEmpty ? records.first : null;

        Duration totalDuration = Duration.zero;
        if (todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime != null) {
          totalDuration = todayRecord.checkOutTime!.toLocal().difference(todayRecord.checkInTime!.toLocal());
        } else if (todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime == null) {
          totalDuration = now.difference(todayRecord.checkInTime!.toLocal());
        }

        final String? remark = todayRecord?.remarks?.trim();
        final bool isActiveSession = todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime == null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Text('Attendance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF101828))),
              const SizedBox(width: 12), Text(_formatDateHeader(now), style: const TextStyle(color: Color(0xFF667085)))]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _smallCard(title: 'CHECK IN', time: _formatDateTime(todayRecord?.checkInTime), statusText: (todayRecord?.checkInTime != null) ? 'Checked In' : 'Not Yet', iconBackground: const Color(0xFFEFF7FF), icon: Icons.login, active: todayRecord?.checkInTime != null)),
              const SizedBox(width: 12),
              Expanded(child: _smallCard(title: 'CHECK OUT', time: _formatDateTime(todayRecord?.checkOutTime), statusText: (todayRecord?.checkOutTime != null) ? 'Checked Out' : 'Not Yet', iconBackground: const Color(0xFFF2F4F7), icon: Icons.logout, active: todayRecord?.checkOutTime != null)),
            ]),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(color: isActiveSession ? const Color(0xFFECFDF5) : Colors.white, borderRadius: BorderRadius.circular(14), border: isActiveSession ? Border.all(color: const Color(0xFF10B981), width: 1.5) : null, boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: const Offset(0, 6))]),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF3F7FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.access_time, color: Color(0xFF6366F1))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TOTAL HOURS', style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w600, fontSize: 12)), const SizedBox(height: 6), Text(_formatDuration(totalDuration), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF101828))),])), if (isActiveSession) Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle)), const SizedBox(width: 8), const Text('ACTIVE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600))])]),
            ),

            const SizedBox(height: 12),

            if (remark != null && remark.isNotEmpty) ...[
              Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 8, offset: const Offset(0, 4))]), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF101828))), const SizedBox(height: 8), Text(remark, style: const TextStyle(fontSize: 14, color: Color(0xFF344054)))])),
              const SizedBox(height: 12),
            ],

            SizedBox(height: 56, width: double.infinity, child: ElevatedButton(onPressed: state is AttendanceActionInProgress ? null : () async { final pos = await _determinePosition(context); if (pos == null) return; context.read<AttendanceBloc>().add(MarkAttendance(latitude: pos.latitude, longitude: pos.longitude)); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: state is AttendanceActionInProgress ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), const SizedBox(width: 12), Text('Processing...', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)), ]) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [ const SizedBox(width: 12), Text(todayRecord == null || todayRecord.checkInTime == null ? 'Check In' : (todayRecord.checkOutTime == null ? 'Check Out' : 'Check In'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)), ]))),
          ],
        );
      },
    );
  }
}

Widget _smallCard({String? title, String? time, String? statusText, Color? iconBackground, IconData? icon, bool active = false}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8, offset: const Offset(0, 6))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBackground ?? const Color(0xFFEFF7FF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF06B6D4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (title ?? '').toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF667085), fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          time ?? '--:--',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF101828)),
        ),

        const SizedBox(height: 6),

        Text(
          statusText ?? '',
          style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
        ),
      ],
    ),
  );
}


class DashboardAttendanceCard extends StatelessWidget {
  final String? userName;
  const DashboardAttendanceCard({Key? key, this.userName}) : super(key: key);

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--:--';
    final l = dt.toLocal();
    final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final ampm = l.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')} $ampm';
  }

  String _formatDurationShort(Duration d) {
    // Return hours, minutes and seconds so UI shows a ticking clock while active
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final s = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '${h}h ${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is AttendanceLoading || state is AttendanceInitial) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color.fromRGBO(0,0,0,0.03), blurRadius: 8, offset: const Offset(0,6))]),
            padding: const EdgeInsets.all(16),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is AttendanceError) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color.fromRGBO(0,0,0,0.03), blurRadius: 8, offset: const Offset(0,6))]),
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Error: ${state.message}')),
          );
        }

        final List<AttendanceRecord> records = state is AttendanceLoaded ? state.records : <AttendanceRecord>[];
        final DateTime now = state is AttendanceLoaded ? state.now : DateTime.now();
        final AttendanceRecord? today = records.isNotEmpty ? records.first : null;
        final bool isActive = today != null && today.checkInTime != null && today.checkOutTime == null;

        Duration totalDuration = Duration.zero;
        if (today != null && today.checkInTime != null && today.checkOutTime != null) {
          totalDuration = today.checkOutTime!.toLocal().difference(today.checkInTime!.toLocal());
        } else if (today != null && today.checkInTime != null && today.checkOutTime == null) {
          totalDuration = now.difference(today.checkInTime!.toLocal());
        }

        final String? remark = today?.remarks?.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // two small cards (check in / check out)
            Row(children: [
              Expanded(child: _smallCard(title: 'CHECK IN', time: _formatTime(today?.checkInTime), statusText: (today?.checkInTime != null) ? 'Checked In' : 'Not Yet', iconBackground: const Color(0xFFEFF7FF), icon: Icons.login, active: today?.checkInTime != null)),
              const SizedBox(width: 12),
              Expanded(child: _smallCard(title: 'CHECK OUT', time: _formatTime(today?.checkOutTime), statusText: (today?.checkOutTime != null) ? 'Checked Out' : 'Not Yet', iconBackground: const Color(0xFFF2F4F7), icon: Icons.logout, active: today?.checkOutTime != null)),
            ]),

            const SizedBox(height: 12),

            // total working hours card
            Container(
              decoration: BoxDecoration(color: isActive ? const Color(0xFFECFDF5) : Colors.white, borderRadius: BorderRadius.circular(14), border: isActive ? Border.all(color: const Color(0xFF10B981), width: 1.5) : null, boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: const Offset(0, 6))]),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF3F7FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.access_time, color: Color(0xFF6366F1))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TOTAL WORKING HOURS', style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w600, fontSize: 12)), const SizedBox(height: 6), Text(_formatDurationShort(totalDuration), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF101828)))])),
                if (isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)), child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600)))
              ]),
            ),

            const SizedBox(height: 12),

            // remarks
            if (remark != null && remark.isNotEmpty) ...[
              Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 8, offset: const Offset(0, 4))]), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF101828))), const SizedBox(height: 8), Text(remark, style: const TextStyle(fontSize: 14, color: Color(0xFF344054)))])),
              const SizedBox(height: 12),
            ],

            // primary button
            SizedBox(
              height: 56,
              width: double.infinity,
              child: Builder(builder: (ctx) {
                final isProcessing = state is AttendanceActionInProgress;
                final label = (today == null || today.checkInTime == null) ? 'Check In' : (today.checkOutTime == null ? 'Check Out' : 'Check In');
                return ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final pos = await determinePositionWithDialog(ctx);
                          if (pos == null) return;
                          ctx.read<AttendanceBloc>().add(MarkAttendance(latitude: pos.latitude, longitude: pos.longitude));
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: isProcessing
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)), SizedBox(width: 12), Text('Processing...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))])
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [ const SizedBox(width: 12), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class SelectedBranchHeader extends StatelessWidget {
  const SelectedBranchHeader({Key? key}) : super(key: key);

  Future<BranchEntity?> _loadSelected(BuildContext context) async {
    final tokenManager = RepositoryProvider.of<TokenManager>(context);
    final branchRepo = RepositoryProvider.of<BranchRepository>(context);
    try {
      final id = await tokenManager.readSelectedBranchId();
      final list = await branchRepo.listBranches();
      if (list.isEmpty) return null;
      if (id == null) return list.first;
      return list.firstWhere((b) => b.id == id, orElse: () => list.first);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BranchEntity?>(
      future: _loadSelected(context),
      builder: (ctx, snap) {
        final branch = snap.data;
        final logoUrl = branch?.consultancyLogo;
        final name = branch?.consultancyName ?? 'OSOM';

        return LayoutBuilder(builder: (ctx, constraints) {
          final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 160.0;

          // If very tight space (like a small AppBar leading), show only the logo scaled to available width
          if (maxW < 88) {
            final size = math.min(40.0, maxW);
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: size,
                height: size,
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => SvgPicture.asset('assets/images/logo.svg'))
                    : SvgPicture.asset('assets/images/logo.svg'),
              ),
            );
          }

          // Otherwise show logo + constrained name + watermark. Text uses ellipsis to prevent overflow.
          return Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 40,
                height: 40,
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(logoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => SvgPicture.asset('assets/images/logo.svg'))
                    : SvgPicture.asset('assets/images/logo.svg'),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0, maxW - 48)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF101828))),
                const SizedBox(height: 4),
                // Opacity(opacity: 0.95, child:
                SizedBox( child: SvgPicture.asset('assets/images/osom_watermark.svg', width: 68, height: 12, fit: BoxFit.contain, alignment: Alignment.centerLeft)),
                // ),
              ]),
            ),
          ]);
        });
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _userName;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // Pull-to-refresh handler: triggers attendance list reload and waits for result
  Future<void> _refreshAttendance(BuildContext ctx) async {
    debugPrint('[Dashboard] pull-to-refresh triggered');
    final scaffold = ScaffoldMessenger.of(ctx);
    try {
      final bloc = ctx.read<AttendanceBloc>();
      // dispatch load with forceRefresh to bypass caches
      debugPrint('[Dashboard] dispatching LoadAttendance(forceRefresh: true)');
      bloc.add(LoadAttendance(forceRefresh: true));

      // wait until either loaded or error state is emitted, with a timeout
      await bloc.stream.firstWhere((state) => state is AttendanceLoaded || state is AttendanceError).timeout(const Duration(seconds: 15));
      debugPrint('[Dashboard] refresh completed');
    } catch (e) {
      debugPrint('[Dashboard] refresh failed or timed out: $e');
      // show user-visible feedback so you know refresh attempted but didn't succeed
      scaffold.showSnackBar(const SnackBar(content: Text('Failed to refresh attendance')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserName());
  }

  Future<void> _loadUserName() async {
    try {
      final userRepo = RepositoryProvider.of<UserRepository?>(context, listen: false);
      if (userRepo != null) {
        try {
          final user = await userRepo.me();
          _userName = user.fullName;
        } catch (_) {
          _userName = null;
        }
      } else {
        _userName = null;
      }
    } finally {
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _handleExpiredSession(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session expired. Please login again.')));
    try {
      context.read<AuthBloc>().add(ForceLogout());
    } catch (_) {}

    final authRepo = RepositoryProvider.of<AuthRepository>(context);
    final tokenManager = RepositoryProvider.of<TokenManager>(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: authRepo,
          child: RepositoryProvider.value(
            value: tokenManager,
            child: BlocProvider<AuthBloc>(
              create: (ctx) => AuthBloc(
                loginUseCase: LoginUseCase(authRepo),
                logoutUseCase: LogoutUseCase(authRepo),
                refreshTokenUseCase: RefreshTokenUseCase(authRepo),
                tokenManager: tokenManager,
                repository: authRepo,
              )..add(AppStarted()),
              child: const LoginPage(),
            ),
          ),
        ),
      ),
      (r) => false,
    );
  }


  @override
  Widget build(BuildContext context) {
    final attendanceRepo = RepositoryProvider.of<AttendanceRepository>(context);
    final listUse = ListAttendanceUseCase(attendanceRepo);
    final markUse = MarkAttendanceUseCase(attendanceRepo);

    return BlocProvider<AttendanceBloc>(
      create: (ctx) => AttendanceBloc(listUseCase: listUse, markUseCase: markUse)..add(LoadAttendance()),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) _handleExpiredSession(context);
          if (state is AuthError) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        },
        child: Scaffold(
          appBar: AppBar(
            leadingWidth: 160,
            // show selected branch logo + name and logout on right
            leading: GestureDetector(
              onTap: () async {
                final changed = await showBranchSelectorOverlay(context);
                if (changed == true) {
                  // Rebuild header to show newly selected branch
                  setState(() {});

                  // Also trigger attendance reload for the new branch (best-effort)
                  try {
                    context.read<AttendanceBloc>().add(LoadAttendance(forceRefresh: true));
                  } catch (_) {}
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: SelectedBranchHeader(),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  // Programmatically show the refresh indicator (useful for testing)
                  try {
                    _refreshKey.currentState?.show();
                  } catch (_) {}
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
               BlocBuilder<AuthBloc, AuthState>(
                 builder: (context, state) {
                   final isLoading = state is AuthLoading;
                   if (isLoading) {
                     return const Padding(
                       padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                       child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white)),
                     );
                   }

                   return Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                     child: InkWell(
                       borderRadius: BorderRadius.circular(10),
                       onTap: () async {
                         final confirmed = await showSignOutDialog(context);
                         if (confirmed == true) context.read<AuthBloc>().add(LogoutRequested());
                       },
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Color.fromRGBO(255, 255, 255, 0.06),
                           borderRadius: BorderRadius.circular(10),
                           border: Border.all(color: Color.fromRGBO(255, 255, 255, 0.12)),
                         ),
                         child: Row(children: const [
                           Icon(Icons.logout, color: Colors.grey, size: 20),
                           SizedBox(width: 8),
                           Text('Logout', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                         ]),
                       ),
                     ),
                   );
                 },
               ),
            ],
          ),
          body: SafeArea(
            child: Builder(builder: (innerCtx) {
              // innerCtx is a BuildContext under the BlocProvider<AttendanceBloc>
              return RefreshIndicator(
                key: _refreshKey,
                onRefresh: () => _refreshAttendance(innerCtx),
                // Use ListView so RefreshIndicator always works even when content is short
                child: ListView(
                  primary: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_greeting()}${_userName != null ? ', $_userName' : ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
                            const SizedBox(height: 4),
                            const Text('Welcome back', style: TextStyle(color: Color(0xFF667085))),
                          ],
                        ),
                        // GestureDetector(
                        //   onTap: () => showBranchSelectorOverlay(context),
                        //   child: SizedBox(width: 64, height: 64, child: SvgPicture.asset('assets/images/osom_watermark.svg')),
                        // ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const DashboardAttendanceCard(),

                    const SizedBox(height: 24),

                    // ...other dashboard content
                    // Add a bottom filler so pull-to-refresh can work on very short content
                    SizedBox(height: MediaQuery.of(innerCtx).size.height * 0.2),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Helper to get device position with permission dialogs. Returns null if user cancelled or permission denied.
Future<Position?> determinePositionWithDialog(BuildContext context) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    final open = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Location services disabled'), content: const Text('Please enable location services to mark attendance.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open settings'))]));
    if (open == true) await Geolocator.openLocationSettings();
    return null;
  }

  LocationPermission permission;
  try {
    permission = await Geolocator.checkPermission();
  } catch (e) {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Location permissions not configured'), content: const Text('No location permissions are defined in the Android manifest. Please ensure ACCESS_FINE_LOCATION or ACCESS_COARSE_LOCATION is added.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
    return null;
  }

  if (permission == LocationPermission.denied) {
    final ask = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Location permission required'), content: const Text('This app needs location permission to mark your attendance.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Allow'))]));
    if (ask != true) return null;
    try {
      permission = await Geolocator.requestPermission();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to request location permission')));
      return null;
    }
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    final open = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Permission permanently denied'), content: const Text('Location permission is permanently denied. Please open app settings to grant permission.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open settings'))]));
    if (open == true) await Geolocator.openAppSettings();
    return null;
  }

  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    return null;
  }
}

// Custom sign-out dialog with improved styling
Future<bool?> showSignOutDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Sign out',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.86,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).dialogTheme.backgroundColor ?? Theme.of(ctx).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 28)),
              const SizedBox(height: 16),
              const Text('Sign out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Are you sure you want to sign out from your account?', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF667085))),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: TextButton(onPressed: () => Navigator.of(ctx).pop(false), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Sign Out', style: TextStyle(color: Colors.white)))),
              ])
             ]),
           ),
         ),
       );
     },
     transitionBuilder: (ctx, anim1, anim2, child) {
       return ScaleTransition(scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack), child: FadeTransition(opacity: anim1, child: child));
     },
   );
}

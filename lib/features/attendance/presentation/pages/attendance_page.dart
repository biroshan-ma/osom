import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';
import '../../domain/usecases/list_attendance_usecase.dart';
import '../../domain/usecases/mark_attendance_usecase.dart';
import '../../domain/repository/attendance_repository.dart';
import '../../domain/entities/attendance_entity.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  // The bloc now manages ticking; UI reads `now` from AttendanceLoaded state.
  bool _isLoadingDialogVisible = false;
  @override
  void initState() {
    super.initState();
  }

  void _showLoadingDialog(BuildContext context) {
    if (_isLoadingDialogVisible) return;
    _isLoadingDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    ).catchError((_) {});
  }

  void _hideLoadingDialog(BuildContext context) {
    if (!_isLoadingDialogVisible) return;
    _isLoadingDialogVisible = false;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }

  Future<Position?> _determinePosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Ask the user to turn on location services
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location services disabled'),
          content: const Text('Please enable location services to mark attendance.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open settings')),
          ],
        ),
      );
      if (open == true) {
        await Geolocator.openLocationSettings();
      }
      return null;
    }

    try {
      permission = await Geolocator.checkPermission();
    } catch (e, st) {
      // This commonly happens when the AndroidManifest is missing location permissions
      debugPrint('Geolocator.checkPermission failed: $e\n$st');
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location permissions not configured'),
          content: const Text('No location permissions are defined in the Android manifest. Please ensure ACCESS_FINE_LOCATION or ACCESS_COARSE_LOCATION is added to android/app/src/main/AndroidManifest.xml'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
      return null;
    }

    // Debug: surface current permission to help diagnose flow
    debugPrint('Geolocation permission state before request: $permission');

    // If permission is denied (but not permanently), show rationale then request
    if (permission == LocationPermission.denied) {
      final ask = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location permission required'),
          content: Text('This app needs location permission to mark your attendance (check-in / check-out).\n\nCurrent permission: $permission\n\nPress Allow to open the system permission prompt.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Allow')),
          ],
        ),
      );
      if (ask != true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return null;
      }

      try {
        permission = await Geolocator.requestPermission();
      } catch (e, st) {
        debugPrint('Geolocator.requestPermission failed: $e\n$st');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to request location permission')));
        return null;
      }
      debugPrint('Geolocation permission state after request: $permission');

      // Show quick dialog explaining the result (helps debugging in-case system dialog doesn't appear)
      if (permission == LocationPermission.denied) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Permission result'), content: const Text('Permission was denied (user refused the system prompt or the system did not show a prompt).'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))]));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return null;
      }
    }

    // If permissions are permanently denied, guide user to app settings
    if (permission == LocationPermission.deniedForever) {
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission permanently denied'),
          content: const Text('Location permission is permanently denied. Please open app settings to grant permission.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open settings')),
          ],
        ),
      );
      if (open == true) {
        await Geolocator.openAppSettings();
      }
      return null;
    }

    // At this point permission should be granted (whileInUse or always)
    try {
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
    final repo = RepositoryProvider.of<AttendanceRepository>(context);
    final listUse = ListAttendanceUseCase(repo);
    final markUse = MarkAttendanceUseCase(repo);

    // If an AttendanceBloc is already provided above (e.g. Dashboard), reuse it; otherwise create our own.
    AttendanceBloc? existingBloc;
    try {
      existingBloc = BlocProvider.of<AttendanceBloc>(context);
    } catch (_) {
      existingBloc = null;
    }

    final attendanceBloc = existingBloc ?? AttendanceBloc(listUseCase: listUse, markUseCase: markUse)..add(LoadAttendance());

    return existingBloc != null
        ? BlocProvider.value(
            value: attendanceBloc,
            child: Scaffold(
              backgroundColor: const Color(0xFFF6F8FB),
              // appBar: AppBar(title: const Text('Attendance')),
              body: _attendanceBody(attendanceBloc),
            ),
          )
        : BlocProvider(
            create: (_) => attendanceBloc,
            child: Scaffold(
              backgroundColor: const Color(0xFFF6F8FB),
              // appBar: AppBar(title: const Text('Attendance')),
              body: _attendanceBody(attendanceBloc),
            ),
          );
  }

  Widget _attendanceBody(AttendanceBloc attendanceBloc) {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listener: (context, state) {
        // Show a full-screen loading dialog when a list load is in progress
        if (state is AttendanceLoading) {
          _showLoadingDialog(context);
        } else if (state is AttendanceLoaded || state is AttendanceError) {
          _hideLoadingDialog(context);
        }

        if (state is AttendanceActionInProgress) {
          // mark-in-progress - ensure any list loading dialog is hidden and the button will show inline spinner
          _hideLoadingDialog(context);
        }

        if (state is AttendanceActionSuccess) {
          // Show success message (bloc will reload list)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message ?? 'Attendance recorded')));
        }
        if (state is AttendanceActionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${state.message}')));
        }
      },
      builder: (context, state) {
        if (state is AttendanceLoading || state is AttendanceInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is AttendanceError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        final List<AttendanceRecord> records = state is AttendanceLoaded ? state.records : <AttendanceRecord>[];
        final DateTime now = state is AttendanceLoaded ? state.now : DateTime.now();
        // assume API returns today's attendance as first item when available
        final AttendanceRecord? todayRecord = records.isNotEmpty ? records.first : null;

        Duration totalDuration = Duration.zero;
        if (todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime != null) {
          totalDuration = todayRecord.checkOutTime!.toLocal().difference(todayRecord.checkInTime!.toLocal());
        } else if (todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime == null) {
          totalDuration = now.difference(todayRecord.checkInTime!.toLocal());
        }

        // Extract today's remark (if any)
        final String? remark = todayRecord?.remarks?.trim();

        // active session is determined from the list API
        final bool isActiveSession = todayRecord != null && todayRecord.checkInTime != null && todayRecord.checkOutTime == null;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Styled back control: a white rounded card with shadow and teal icon
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          // color: Colors.white,
                          // borderRadius: BorderRadius.circular(14),
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: const Color.fromRGBO(16, 24, 40, 0.06),
                          //     blurRadius: 10,
                          //     offset: const Offset(0, 4),
                          //   ),
                          // ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF7FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_back, color: Color(0xFF06B6D4)),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Attendance',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Color(0xFF101828),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                  child: Text(_formatDateHeader(now), style: const TextStyle(color: Color(0xFF667085), fontSize: 16)),
                ),
                const SizedBox(height: 20),

                // Check cards
                Row(
                  children: [
                    Expanded(
                      child: _smallCard(
                        title: 'CHECK IN',
                        time: _formatDateTime(todayRecord?.checkInTime),
                        statusText: (todayRecord?.checkInTime != null) ? 'Checked In' : 'Not Yet',
                        iconBackground: const Color(0xFFEFF7FF),
                        icon: Icons.login,
                        active: todayRecord?.checkInTime != null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _smallCard(
                        title: 'CHECK OUT',
                        time: _formatDateTime(todayRecord?.checkOutTime),
                        statusText: (todayRecord?.checkOutTime != null) ? 'Checked Out' : 'Not Yet',
                        iconBackground: const Color(0xFFF2F4F7),
                        icon: Icons.logout,
                        active: todayRecord?.checkOutTime != null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Total hours
                Container(
                  // switch background/border when active
                  decoration: BoxDecoration(
                    color: isActiveSession ? const Color(0xFFECFDF5) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isActiveSession ? Border.all(color: const Color(0xFF10B981), width: 1.5) : null,
                    boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: const Offset(0, 6))],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF3F7FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.access_time, color: Color(0xFF6366F1))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('TOTAL HOURS', style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(_formatDuration(totalDuration), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF101828))),
                        ]),
                      ),

                      // Active indicator: green dot + ACTIVE text when active
                      if (isActiveSession)
                        Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          const Text('ACTIVE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                        ])
                      else
                        const SizedBox.shrink(),

                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Remarks (show only when present)
                if (remark != null && remark.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF101828))),
                        const SizedBox(height: 8),
                        Text(remark, style: const TextStyle(fontSize: 14, color: Color(0xFF344054))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Main button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: state is AttendanceActionInProgress
                        ? null
                        : () async {
                            final pos = await _determinePosition(context);
                            if (pos == null) return;
                            context.read<AttendanceBloc>().add(MarkAttendance(latitude: pos.latitude, longitude: pos.longitude));
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: state is AttendanceActionInProgress
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text('Processing...', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          ])
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.fingerprint, color: Colors.black87),
                            const SizedBox(width: 12),
                            Text(todayRecord == null || todayRecord.checkInTime == null ? 'Check In' : (todayRecord.checkOutTime == null ? 'Check Out' : 'Check In'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                          ]),

                  ),
                ),

                const SizedBox(height: 22),

                // Activity header
                // Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                //   const Text('Your Activity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                //   const Text('View All', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w600, fontSize: 14)),
                // ]),
                //
                // const SizedBox(height: 12),
                //
                // // Activity list
                // Column(
                //   children: records.map((r) {
                //     final isCheckout = r.checkOutTime != null && (r.checkInTime == null || (r.checkOutTime!.isAfter(r.checkInTime!)));
                //     final date = r.date != null ? r.date!.toLocal().toIso8601String().split('T').first : '—';
                //     final time = r.checkOutTime != null ? _formatDateTime(r.checkOutTime) : (r.checkInTime != null ? _formatDateTime(r.checkInTime) : '--:--:--');
                //     return Container(
                //       margin: const EdgeInsets.only(bottom: 12),
                //       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 8, offset: const Offset(0, 4))]),
                //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                //       child: Row(children: [
                //         Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(10)), child: Icon(isCheckout ? Icons.logout : Icons.login, color: const Color(0xFF344054))),
                //         const SizedBox(width: 12),
                //         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isCheckout ? 'checkout' : 'checkin', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 4), Text(date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))])),
                //         Text(time, style: const TextStyle(color: Color(0xFF101828), fontSize: 14)),
                //       ]),
                //     );
                //   }).toList(),
                // ),
              ],
            ),
          ));
        },
      );
  }
}

Widget _smallCard({required String title, required String time, required String statusText, required Color iconBackground, required IconData icon, required bool active}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: const Offset(0, 6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF06B6D4))),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF667085), fontWeight: FontWeight.w700)))
      ]),
      const SizedBox(height: 12),
      Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
      const SizedBox(height: 6),
      Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
    ]),
  );
}

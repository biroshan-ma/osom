import 'package:flutter/material.dart';
import '../services/version_check_service.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionGate extends StatefulWidget {
  final Widget child;
  final String owner;
  final String repo;
  final bool force; // if true, force update when newer release exists

  const VersionGate({super.key, required this.child, required this.owner, required this.repo, this.force = true});

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  final VersionCheckService _svc = VersionCheckService();
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final latest = await _svc.fetchLatestRelease(widget.owner, widget.repo);
    if (latest == null) {
      setState(() => _checked = true);
      return;
    }
    final local = await _svc.getLocalVersion();
    if (_svc.isUpdateAvailable(local, latest.tagName)) {
      // show blocking dialog
      if (mounted) {
        await showDialog<void>(
          barrierDismissible: !widget.force,
          context: context,
          builder: (ctx) => WillPopScope(
            onWillPop: () async => !widget.force,
            child: AlertDialog(
              title: Text('Update available: ${latest.tagName}'),
              content: SingleChildScrollView(child: Text(latest.body.isEmpty ? 'A newer version is available.' : latest.body)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final url = latest.htmlUrl;
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/branch_repository.dart';
import '../../../../core/network/token_manager.dart';
import '../../domain/entities/branch_entity.dart';

class BranchSelectorPage extends StatefulWidget {
  final BranchRepository repository;
  final TokenManager tokenManager;

  const BranchSelectorPage({super.key, required this.repository, required this.tokenManager});

  @override
  State<BranchSelectorPage> createState() => _BranchSelectorPageState();
}

class _BranchSelectorPageState extends State<BranchSelectorPage> {
  late final BranchRepository _repo;
  late final TokenManager _tokenManager;
  List<BranchEntity> _branches = [];
  bool _loading = true;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository;
    _tokenManager = widget.tokenManager;
    // We'll schedule _load in post frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final list = await _repo.listBranches();
      final saved = await _tokenManager.readSelectedBranchId();
      if (!mounted) return;
      setState(() {
        _branches = list;
        _selectedId = saved ?? (list.isNotEmpty ? list.first.id : null);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load branches: $e')));
    }
  }

  Future<void> _saveSelection() async {
    if (_selectedId == null) return;
    await _tokenManager.saveSelectedBranchId(_selectedId!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Branch selected')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Branch'),
        actions: [
          TextButton(
            onPressed: _saveSelection,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _branches.length,
              itemBuilder: (context, index) {
                final b = _branches[index];
                return ListTile(
                  leading: b.consultancyLogo != null && b.consultancyLogo!.isNotEmpty
                      ? SizedBox(width: 48, height: 48, child: Image.network(b.consultancyLogo!, fit: BoxFit.cover))
                      : null,
                  title: Text(b.consultancyName),
                  subtitle: Text(b.consultancyDesc),
                  trailing: _selectedId == b.id ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () => setState(() => _selectedId = b.id),
                );
              },
            ),
    );
  }
}

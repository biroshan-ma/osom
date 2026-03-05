import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/bloc/profile_bloc.dart';
import '../../presentation/bloc/profile_event.dart';
import '../../presentation/bloc/profile_state.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_manager.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = RepositoryProvider.of<ApiClient>(context);
    final tokenManager = RepositoryProvider.of<TokenManager>(context);

    // Optional preloaded display name provided at app init to avoid showing a loader
    final preloadedName = RepositoryProvider.of<String?>(context, listen: false);

    // Derive defaultSuffix from ApiClient baseUrl as best-effort
    String defaultSuffix = '.osom.global';
    try {
      final base = api.dio.options.baseUrl;
      if (base.contains('localhost')) defaultSuffix = '.localhost:5173/';
    } catch (_) {}

    return BlocProvider(
      create: (ctx) => ProfileBloc(apiClient: api, tokenManager: tokenManager, defaultSuffix: defaultSuffix)..add(LoadProfile()),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            if (preloadedName != null && preloadedName.isNotEmpty) {
              return Center(child: Text('Welcome $preloadedName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => context.read<ProfileBloc>().add(LoadProfile()), child: const Text('Retry')),
                ],
              ),
            );
          }

          if (state is ProfileLoaded) {
            return Center(child: Text('Welcome ${state.displayName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

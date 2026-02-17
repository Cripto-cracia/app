import 'package:flutter/material.dart';

import '../config/constants.dart';

/// Placeholder home screen displayed on app launch.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: const Center(child: Text('Welcome to ${AppConstants.appName}')),
    );
  }
}

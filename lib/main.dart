import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

void main() async {
  // Necesario para flutter_secure_storage antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SnowPartyApp(),
    ),
  );
}

class SnowPartyApp extends ConsumerWidget {
  const SnowPartyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Snow Party',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
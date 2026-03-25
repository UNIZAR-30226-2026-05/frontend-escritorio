import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  // Necesario para flutter_secure_storage antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // LIMPIEZA DE SESIÓN (TEMPORAL)
  // Borra el token antiguo que sobrevivió en el sistema operativo
  await const FlutterSecureStorage().deleteAll();
  
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
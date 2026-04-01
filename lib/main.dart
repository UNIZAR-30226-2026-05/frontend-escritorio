import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/lobby/data/lobby_websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SnowPartyApp(),
    ),
  );
}

class SnowPartyApp extends ConsumerStatefulWidget {
  const SnowPartyApp({super.key});

  @override
  ConsumerState<SnowPartyApp> createState() => _SnowPartyAppState();
}

// WidgetsBindingObserver permite interceptar eventos del ciclo de vida de la app,
// incluyendo el intento de cierre de ventana en escritorio (didRequestAppExit).
class _SnowPartyAppState extends ConsumerState<SnowPartyApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    // Registra este widget como observador del ciclo de vida de la app.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Se ejecuta cuando el usuario intenta cerrar la ventana (solo escritorio).
  // Desconecta el WS del lobby antes de permitir el cierre.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    ref.read(lobbyWebSocketProvider).disconnect();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
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

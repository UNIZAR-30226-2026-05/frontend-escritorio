import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/router/app_router.dart';
import 'features/board/data/websocket_service.dart';
import 'features/lobby/data/lobby_websocket_service.dart';
import 'features/lobby/data/session_websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    fullScreen: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setFullScreen(true);
    await windowManager.show();
    await windowManager.focus();
  });

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
  // Cierra todos los WebSockets abiertos. Llamar disconnect() en uno ya cerrado
  // es un no-op, así que es seguro hacerlo incondicionalmente.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    ref.read(webSocketProvider).disconnect();
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(sessionWebSocketProvider).disconnect();
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
        fontFamily: 'Retro Gaming',
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

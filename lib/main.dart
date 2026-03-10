import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/board/presentation/board_screen.dart';

void main() {
  runApp(
    // ProviderScope es obligatorio para usar Riverpod
    const ProviderScope(
      child: SnowPartyApp(),
    ),
  );
}

class SnowPartyApp extends StatelessWidget {
  const SnowPartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snow Party MVP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      //TODO Eliminar e implementar go_router para el manejo de sesiones y usuarios5
      home: const BoardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

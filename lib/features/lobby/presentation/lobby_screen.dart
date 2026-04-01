import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lobby_websocket_service.dart';
import 'controllers/lobby_provider.dart';
import '../../auth/presentation/controllers/auth_provider.dart';

// Pantalla del lobby: el usuario puede crear una partida o unirse con código.
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  // Controlador del campo de texto para el código de partida al unirse.
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // Crea una nueva partida y conecta el WS del lobby con el game_id obtenido.
  Future<void> _crearPartida() async {
    // Desconecta el WS y limpia la sesión anterior por si ya estaba en otra partida.
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    final token = ref.read(authProvider).token!;
    final success =
        await ref.read(lobbyProvider.notifier).crearPartida(token);
    if (success && mounted) {
      final gameId = ref.read(lobbyProvider).gameId!;
      ref.read(lobbyWebSocketProvider).connect(gameId, token);
    }
  }

  // Une al usuario a una partida existente mediante el código introducido.
  // Desconecta el WS actual antes de conectar al nuevo para evitar conexiones huérfanas.
  void _unirseConCodigo() {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final token = ref.read(authProvider).token!;
    // Desconecta y limpia la sesión anterior antes de intentar unirse.
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    ref.read(lobbyProvider.notifier).unirseAPartida(code);
    ref.read(lobbyWebSocketProvider).connect(code, token);
  }

  // Cierra sesión, resetea el estado del lobby y desconecta el WS.
  Future<void> _logout() async {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).reset();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    // Cuando el backend confirma que la partida ha empezado, navega al tablero.
    ref.listen<LobbyState>(lobbyProvider, (prev, next) {
      if (prev != null && !prev.gameStarted && next.gameStarted) {
        ref.read(lobbyWebSocketProvider).disconnect();
        context.go('/game');
      }
      // Cuando este dispositivo es desplazado por otro, muestra aviso y limpia la sesión.
      if (prev != null && !prev.forceDisconnected && next.forceDisconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.serverMessage.isNotEmpty
                ? next.serverMessage
                : 'Sesión iniciada en otro dispositivo'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(lobbyProvider.notifier).clearForceDisconnected();
      }
    });

    final lobbyState = ref.watch(lobbyProvider);
    final username = ref.watch(authProvider).username ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby — $username'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // --- Mensaje de error ---
            if (lobbyState.error != null)
              Text(
                lobbyState.error!,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 16),

            // --- Botón crear partida ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: lobbyState.isLoading || lobbyState.gameId != null
                    ? null
                    : _crearPartida,
                child: lobbyState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Crear partida'),
              ),
            ),

            const SizedBox(height: 24),

            // --- Info de la partida creada/unida ---
            if (lobbyState.gameId != null) ...[
              Text(
                'Código de partida: ${lobbyState.gameId}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (lobbyState.serverMessage.isNotEmpty)
                Text(lobbyState.serverMessage),
              const SizedBox(height: 16),

              // --- Slots de jugadores (máximo 4) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final player = i < lobbyState.playersConnected.length
                      ? lobbyState.playersConnected[i]
                      : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Chip(
                      label: Text(player ?? 'Vacío'),
                      backgroundColor:
                          player != null ? Colors.green : Colors.grey,
                    ),
                  );
                }),
              ),
            ],

            const Spacer(),

            // --- Unirse con código ---
            const Text(
              'Unirse a una partida con código',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Introduce el código',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      lobbyState.gameId != null ? null : _unirseConCodigo,
                  child: const Text('Unirse'),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

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

  // Desconecta el WS y limpia la sesión de partida actual (abandonar partida).
  void _abandonarPartida() {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
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
  Future<void> _unirseConCodigo() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final token = ref.read(authProvider).token!;
    // Desconecta y limpia la sesión anterior antes de intentar unirse.
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    // Primero valida que la partida existe y tiene hueco.
    // Solo si el servidor acepta conectamos el WS.
    final accepted = await ref.read(lobbyProvider.notifier).unirsePartida(code, token);
    if (accepted) {
      ref.read(lobbyWebSocketProvider).connect(code, token);
    }
  }

  // Cierra sesión, resetea el estado del lobby y desconecta el WS.
  Future<void> _logout() async {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).reset();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    // Cuando todos los jugadores han seleccionado personaje, navega al tablero.
    ref.listen<LobbyState>(lobbyProvider, (prev, next) {
      if (prev != null && !prev.allCharactersSelected && next.allCharactersSelected) {
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
      // Si el error es de autenticación, cierra sesión y GoRouter redirige a /login.
      if (prev != null && next.error != null && next.error != prev.error) {
        final error = next.error!.toLowerCase();
        if (error.contains('autenticad') || error.contains('unauthorized') || error.contains('401')) {
          _logout();
        }
      }
    });

    final lobbyState = ref.watch(lobbyProvider);
    final username = ref.watch(authProvider).username ?? '';

    // Si el juego ha empezado pero no todos han elegido personaje, 
    // mostramos la interfaz de selección.
    if (lobbyState.gameId != null && lobbyState.gameStarted && !lobbyState.allCharactersSelected) {
      return Scaffold(
        extendBodyBehindAppBar: true, // Para que la imagen cubra todo hasta arriba
        appBar: AppBar(
          title: Text('Menú de Selección — $username', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: CharacterSelectionView(lobbyState: lobbyState, currentUsername: username),
      );
    }

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
            if (lobbyState.gameId == null)
              const Text(
                'Crea una partida para obtener un código',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            if (lobbyState.gameId != null) ...[
              Text(
                'Código de partida: ${lobbyState.gameId}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (lobbyState.serverMessage.isNotEmpty)
                Text(lobbyState.serverMessage),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _abandonarPartida,
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: const Text(
                  'Abandonar partida',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 8),

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

// Widget encargado de la interfaz de selección de personajes
class CharacterSelectionView extends ConsumerStatefulWidget {
  final LobbyState lobbyState;
  final String currentUsername;

  const CharacterSelectionView({
    super.key,
    required this.lobbyState,
    required this.currentUsername,
  });

  @override
  ConsumerState<CharacterSelectionView> createState() => _CharacterSelectionViewState();
}

class _CharacterSelectionViewState extends ConsumerState<CharacterSelectionView> {
  final List<String> _availableCharacters = ['Banquero', 'Videojugador', 'Escapista', 'Vidente'];
  Timer? _timer;
  int _timeLeft = 10;
  bool _isMyTurn = false;

  @override
  void initState() {
    super.initState();
    _checkTurnAndStartTimer();
  }

  @override
  void didUpdateWidget(CharacterSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia el número de personajes seleccionados, revisamos si ahora es nuestro turno
    if (oldWidget.lobbyState.selectedCharacters.length != widget.lobbyState.selectedCharacters.length) {
      _checkTurnAndStartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkTurnAndStartTimer() {
    // Calculamos de quién es el turno
    // order = selectedCharacters.length + 1
    // Y comparamos con nuestra posición en la lista de playersConnected
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    final miOrden = widget.lobbyState.playersConnected.indexOf(widget.currentUsername) + 1;

    final ahoraEsMiTurno = (numPersonajes + 1) == miOrden;

    // Si ya he seleccionado, ya no es mi turno
    final yaHeSeleccionado = widget.lobbyState.selectedCharacters.containsKey(widget.currentUsername);

    if (ahoraEsMiTurno && !yaHeSeleccionado) {
      if (!_isMyTurn) {
        // Empieza mi turno
        setState(() {
          _isMyTurn = true;
          _timeLeft = 10;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_timeLeft > 0) {
            setState(() => _timeLeft--);
          } else {
            // El tiempo se agotó, hacer selección automática
            timer.cancel();
            _autoSelectRandomCharacter();
          }
        });
      }
    } else {
      // Ya no es nuestro turno o nunca lo fue
      if (_isMyTurn) {
        setState(() => _isMyTurn = false);
        _timer?.cancel();
      }
    }
  }

  void _autoSelectRandomCharacter() {
    final takenCharacters = widget.lobbyState.selectedCharacters.values.toList();
    final remaining = _availableCharacters.where((c) => !takenCharacters.contains(c)).toList();
    if (remaining.isNotEmpty) {
      final randomChar = remaining[Random().nextInt(remaining.length)];
      ref.read(lobbyWebSocketProvider).sendCharacterSelection(randomChar);
    }
  }

  void _selectCharacter(String character) {
    if (!_isMyTurn) return;
    
    // Comprobar si no está pillado
    if (widget.lobbyState.selectedCharacters.containsValue(character)) return;

    // Cancelamos timer para que no salte
    _timer?.cancel();
    setState(() => _isMyTurn = false);
    
    // Enviamos petición por socket
    ref.read(lobbyWebSocketProvider).sendCharacterSelection(character);
  }

  @override
  Widget build(BuildContext context) {
    // Averiguar a quién le toca elegir ahora para mostrarlo en grande
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    String jugadorActual = '';
    if (numPersonajes < widget.lobbyState.playersConnected.length) {
      jugadorActual = widget.lobbyState.playersConnected[numPersonajes];
    } else {
      jugadorActual = 'Esperando a los demás...';
    }

    return Stack(
      children: [
        // Fondo del tablero oscurecido
        Positioned.fill(
          child: Image.asset(
            'assets/images/board/tablero_def.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.75), // Oscurecimiento superpuesto
          ),
        ),
        
        // Contenido interactivo
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isMyTurn ? Colors.greenAccent : Colors.blueAccent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isMyTurn ? '¡ES TU TURNO!' : 'Turno de: $jugadorActual',
                        style: TextStyle(
                          fontSize: 26, 
                          fontWeight: FontWeight.bold,
                          color: _isMyTurn ? Colors.greenAccent : Colors.white,
                        ),
                      ),
                      if (_isMyTurn) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tiempo restante: $_timeLeft s',
                          style: const TextStyle(fontSize: 20, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _availableCharacters.map((character) {
                      // Estado del personaje
                      final isTaken = widget.lobbyState.selectedCharacters.containsValue(character);
                      String takenBy = '';
                      if (isTaken) {
                        // Buscar quién lo tiene
                        widget.lobbyState.selectedCharacters.forEach((user, char) {
                          if (char == character) takenBy = user;
                        });
                      }
                      
                      final isMySelection = takenBy == widget.currentUsername;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              if (isTaken || !_isMyTurn) return;
                              _selectCharacter(character);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: isMySelection 
                                    ? Colors.green.withOpacity(0.3) 
                                    : (isTaken ? Colors.grey.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMySelection 
                                      ? Colors.greenAccent 
                                      : (isTaken ? Colors.transparent : Colors.white54),
                                  width: 3,
                                ),
                                boxShadow: [
                                  if (isMySelection)
                                    const BoxShadow(color: Colors.greenAccent, blurRadius: 10, spreadRadius: 2)
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Imagen del personaje
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: isTaken && !isMySelection ? 0.3 : 1.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 60.0), // Dejar espacio para textos
                                          child: Image.asset(
                                            _getImageForCharacter(character),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Textos abajo
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black.withOpacity(0.7),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Column(
                                          children: [
                                            Text(
                                              character,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: isTaken && !isMySelection ? Colors.grey : Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            if (isTaken) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                '✓ $takenBy',
                                                style: const TextStyle(
                                                  color: Colors.redAccent, 
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Icono de bloqueo gigante si está cogido por otros
                                    if (isTaken && !isMySelection)
                                      const Icon(
                                        Icons.lock,
                                        size: 80,
                                        color: Colors.white54,
                                      )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getImageForCharacter(String character) {
    switch (character) {
      case 'Banquero': return 'assets/images/characters/general/banquero_frente_der.png';
      case 'Videojugador': return 'assets/images/characters/general/videojugador_frente_der.png';
      case 'Escapista': return 'assets/images/characters/general/escapista_frente_der.png';
      case 'Vidente': return 'assets/images/characters/general/vidente_frente_der.png';
      default: return 'assets/images/characters/general/banquero_frente_der.png';
    }
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lobby/presentation/controllers/lobby_provider.dart';
import '../../../lobby/data/lobby_websocket_service.dart';
import '../../../../core/widgets/retro_widgets.dart';

class CharacterSelectionModal extends ConsumerStatefulWidget {
  final LobbyState lobbyState;
  final String currentUsername;

  const CharacterSelectionModal({
    super.key,
    required this.lobbyState,
    required this.currentUsername,
  });

  @override
  ConsumerState<CharacterSelectionModal> createState() =>
      _CharacterSelectionModalState();
}

class _CharacterSelectionModalState
    extends ConsumerState<CharacterSelectionModal> {
  final List<String> _availableCharacters = [
    'Banquero',
    'Videojugador',
    'Escapista',
    'Vidente'
  ];

  final Map<String, String> _descripciones = {
    'Banquero':
        'Roba una cantidad de\nmonedas X a un jugador\nelegido por el propio\nbanquero en cada turno.',
    'Videojugador': 'Vota entre dos opciones de\nminijuegos posibles.',
    'Escapista': 'Recibe penalizaciones\nreducidas en eventos\nnegativos.',
    'Vidente':
        'Puede visualizar el\nresultado de los dados\nantes de jugar el\nminijuego de orden para\ntomar decisiones\nestratégicas.',
  };

  Timer? _timer;
  int _timeLeft = 10;
  bool _isMyTurn = false;

  @override
  void initState() {
    super.initState();
    _checkTurnAndStartTimer();
  }

  @override
  void didUpdateWidget(CharacterSelectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lobbyState.selectedCharacters.length !=
        widget.lobbyState.selectedCharacters.length) {
      _checkTurnAndStartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkTurnAndStartTimer() {
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    final miOrden =
        widget.lobbyState.playersConnected.indexOf(widget.currentUsername) + 1;
    final ahoraEsMiTurno = (numPersonajes + 1) == miOrden;
    final yaHeSeleccionado = widget.lobbyState.selectedCharacters
        .containsKey(widget.currentUsername);

    if (ahoraEsMiTurno && !yaHeSeleccionado) {
      if (!_isMyTurn) {
        setState(() {
          _isMyTurn = true;
          _timeLeft = 10;
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_timeLeft > 0) {
            setState(() => _timeLeft--);
          } else {
            timer.cancel();
            _autoSelectRandomCharacter();
          }
        });
      }
    } else {
      if (_isMyTurn) {
        setState(() => _isMyTurn = false);
        _timer?.cancel();
      }
    }
  }

  void _autoSelectRandomCharacter() {
    final takenCharacters =
        widget.lobbyState.selectedCharacters.values.toList();
    final remaining = _availableCharacters
        .where((c) => !takenCharacters.contains(c))
        .toList();
    if (remaining.isNotEmpty) {
      final randomChar = remaining[Random().nextInt(remaining.length)];
      ref.read(lobbyWebSocketProvider).sendCharacterSelection(randomChar);
    }
  }

  void _selectCharacter(String character) {
    if (!_isMyTurn) return;
    if (widget.lobbyState.selectedCharacters.containsValue(character)) return;
    _timer?.cancel();
    setState(() => _isMyTurn = false);
    ref.read(lobbyWebSocketProvider).sendCharacterSelection(character);
  }

  String _getImageForCharacter(String character) {
    switch (character) {
      case 'Banquero':
        return 'assets/images/characters/general/banquero_frente_der.png';
      case 'Videojugador':
        return 'assets/images/characters/general/videojugador_frente_der.png';
      case 'Escapista':
        return 'assets/images/characters/general/escapista_frente_der.png';
      case 'Vidente':
        return 'assets/images/characters/general/vidente_frente_der.png';
      default:
        return 'assets/images/characters/general/banquero_frente_der.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    String jugadorActual = '';
    if (numPersonajes < widget.lobbyState.playersConnected.length) {
      jugadorActual = widget.lobbyState.playersConnected[numPersonajes];
    }

    // Colores fieles a la imagen proporcionada
    const mainBgColor = Color(0xFF2C2255); // Oscuro morado para el cuerpo
    const headerBgColor = Color(0xFF57468B); // Morado más claro cabecera
    const statusBgColor = Color(0xFF1E382B); // Verde barra estado
    const statusTextColor = Color(0xFF6DE899); // Verde brillante texto
    const whiteLineColor = Colors.white;

    return Container(
      width: 1040,
      height: 640,
      decoration: BoxDecoration(
        color: mainBgColor,
        border: Border.all(color: Colors.white, width: 2), // Outer white border
      ),
      child: Column(
        children: [
          // ---------------- 1. CABECERA ----------------
          Container(
            width: double.infinity,
            color: headerBgColor,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Column(
              children: [
                Text(
                  'SELECCIONA TU PERSONAJE',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: 4.0,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Cada héroe tiene habilidades únicas para dominar el tablero',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Linea separadora cabecera
          Container(height: 2, width: double.infinity, color: whiteLineColor),

          // ---------------- 2. BARRA DE ESTADO ----------------
          Container(
            width: double.infinity,
            color: statusBgColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              _isMyTurn
                  ? 'ES TU TURNO DE ELEGIR'
                  : 'TURNO DE ELEGIR DE: ${jugadorActual.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 16,
                color: statusTextColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Linea separadora inferior de la barra de estado
          Container(
              height: 2,
              width: double.infinity,
              color: const Color(0xFF3B9560)),

          // ---------------- 3. TARJETAS DE PERSONAJES ----------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _availableCharacters.map((character) {
                  final isTaken = widget.lobbyState.selectedCharacters
                      .containsValue(character);
                  String takenBy = '';
                  if (isTaken) {
                    widget.lobbyState.selectedCharacters.forEach((user, char) {
                      if (char == character) takenBy = user;
                    });
                  }

                  final isMySelection = takenBy == widget.currentUsername;
                  final bool isActiveCard =
                      isMySelection || (_isMyTurn && !isTaken);
                  final bool canSelect = _isMyTurn && !isTaken;

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 0),
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
                      decoration: BoxDecoration(
                        color: mainBgColor,
                        border: Border.all(
                          color: isActiveCard ? Colors.white : Colors.white38,
                          width: isActiveCard ? 3 : 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Recuadro del Avatar
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1640),
                              border: Border.all(
                                color: isActiveCard
                                    ? Colors.white
                                    : Colors.white38,
                                width: isActiveCard ? 2 : 1,
                              ),
                            ),
                            child: ClipRect(
                              child: Opacity(
                                opacity:
                                    (isTaken && !isMySelection) ? 0.3 : 1.0,
                                child: Transform.scale(
                                  scale: 1.8,
                                  child: Image.asset(
                                    _getImageForCharacter(character),
                                    fit: BoxFit.contain,
                                    alignment: const Alignment(0.0, -0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Título
                          Text(
                            character.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Retro Gaming',
                              fontSize: 16,
                              color: (isTaken && !isMySelection)
                                  ? Colors.white38
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Descripción
                          Expanded(
                            child: Text(
                              _descripciones[character]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: 12,
                                color: (isTaken && !isMySelection)
                                    ? Colors.white24
                                    : Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ),

                          // Botón inferior
                          if (isTaken && !isMySelection)
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1435),
                                border: Border.all(
                                    color: const Color(0xFF2A1D45), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Elegir',
                                  style: TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      color: Colors.white24,
                                      fontSize: 14)),
                            )
                          else if (isActiveCard)
                            RetroImgButton(
                              label: 'Elegir',
                              asset: 'assets/images/ui/btn_verde.png',
                              width: double.infinity,
                              height: 52,
                              fontSize: 14,
                              onTap: canSelect
                                  ? () => _selectCharacter(character)
                                  : null,
                            )
                          else
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1435),
                                border: Border.all(
                                    color: const Color(0xFF2A1D45), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Elegir',
                                  style: TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      color: Colors.white24,
                                      fontSize: 14)),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ---------------- 4. FOOTER ----------------
          Container(
              height: 2,
              width: double.infinity,
              color: const Color(0xFF201640)), // Separador oscuro final
          const SizedBox(height: 16),
          const Text(
            'ELIGE TU PERSONAJE PARA CONTINUAR...',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: 11,
              color: Colors.white38,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

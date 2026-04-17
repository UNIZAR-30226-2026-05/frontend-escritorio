import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lobby/presentation/controllers/lobby_provider.dart';
import '../../../lobby/data/lobby_websocket_service.dart';

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

  Widget _buildElegirButton({VoidCallback? onTap, double opacity = 1.0}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? opacity : 1.0,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ui/btn_verde.png'),
              fit: BoxFit.fill,
            ),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Elegir',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 16,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = Colors.black,
                ),
              ),
              const Text(
                'Elegir',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getImageForCharacter(String character) {
    switch (character) {
      case 'Banquero':
        return 'assets/images/characters/general/banquero_perfil.png';
      case 'Videojugador':
        return 'assets/images/characters/general/videojugador_perfil.png';
      case 'Escapista':
        return 'assets/images/characters/general/escapista_perfil.png';
      case 'Vidente':
        return 'assets/images/characters/general/vidente_perfil.png';
      default:
        return 'assets/images/characters/general/banquero_perfil.png';
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Column(
              children: [
                Text(
                  'SELECCIONA TU PERSONAJE',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 28,
                    color: Colors.white,
                    letterSpacing: 4.0,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Cada héroe tiene habilidades únicas para dominar el tablero',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 13,
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
            padding: const EdgeInsets.symmetric(vertical: 8),
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

                  final bool dimCard = isTaken && !isMySelection;

                  return Expanded(
                    child: Opacity(
                      opacity: dimCard ? 0.4 : 1.0,
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
                            // Recuadro del Avatar (≈1/3 del alto de la tarjeta)
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1640),
                                border: Border.all(
                                  color: isActiveCard
                                      ? Colors.white
                                      : Colors.white38,
                                  width: isActiveCard ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.asset(
                                  _getImageForCharacter(character),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Título
                            Text(
                              character.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: 16,
                                color: Colors.white,
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
                                style: const TextStyle(
                                  fontFamily: 'Retro Gaming',
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ),

                            // Botón inferior
                            if (isActiveCard)
                              _buildElegirButton(
                                onTap: canSelect
                                    ? () => _selectCharacter(character)
                                    : null,
                              )
                            else
                              _buildElegirButton(),
                          ],
                        ),
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
              color: Colors.white70), // Separador mismo tono que el texto
          const SizedBox(height: 16),
          const Text(
            'ELIGE TU PERSONAJE PARA CONTINUAR...',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: 11,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

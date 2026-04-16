import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/websocket_service.dart';
import '../../domain/gamemodels.dart';
import '../controllers/game_provider.dart';
import '../../../../core/widgets/retro_widgets.dart';
import '../board_screen.dart'; // Para reutilizar getCharacterImagePath
import '../../../auth/presentation/controllers/auth_provider.dart'; // <-- IMPORTACIÓN AÑADIDA

class BanqueroModal extends ConsumerWidget {
  final VoidCallback onClose;
  final VoidCallback onSkillUsed;

  const BanqueroModal({
    super.key,
    required this.onClose,
    required this.onSkillUsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final myUsername = ref.watch(authProvider).username;

    // Filtramos para mostrar únicamente al resto de los jugadores
    final otherPlayers =
        gameState.players.where((p) => p.username != myUsername).toList();

    return Container(
      width: 680,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---------------- CABECERA ----------------
          const Text(
            'HABILIDAD DE BANQUERO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Retro Gaming',
              letterSpacing: 2.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '¿A QUIÉN QUIERES ROBAR?',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontFamily: 'Retro Gaming',
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(height: 2, color: Colors.white),
          const SizedBox(height: 24),

          // ---------------- CARTAS DE JUGADORES ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: otherPlayers.map((player) {
              // El Escapista pierde menos monedas (según lógica del backend)
              final isEscapista =
                  player.characterClass == CharacterClass.escapista;
              final amountToRob = isEscapista ? 1 : 2;

              // Verificamos si el jugador tiene fondos suficientes para ser robado
              final canRob = player.coins >= amountToRob;

              return Container(
                width: 170,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.only(
                    top: 24, bottom: 20, left: 16, right: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Esquinas retro integradas en los bordes
                    Positioned(top: -26, left: -18, child: _buildCorner()),
                    Positioned(top: -26, right: -18, child: _buildCorner()),
                    Positioned(bottom: -22, left: -18, child: _buildCorner()),
                    Positioned(bottom: -22, right: -18, child: _buildCorner()),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar del contrincante
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1435),
                            border: Border.all(
                                color: const Color(0xFF4A3E66), width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.asset(
                              getCharacterImagePath(
                                  player.characterClass, true),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nombre
                        Text(
                          player.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Retro Gaming',
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),

                        // Botón de Acción
                        RetroImgButton(
                          label: 'ROBAR $amountToRob¢',
                          asset: 'assets/images/ui/btn_verde.png',
                          width: double.infinity,
                          height: 38,
                          fontSize: 11,
                          onTap: canRob
                              ? () {
                                  // Acción genérica delegada al websocket para el banquero
                                  ref
                                      .read(webSocketProvider)
                                      .sendGenericAction({
                                    'action': 'banquero',
                                    'payload': {'robar_a': player.username}
                                  });
                                  onSkillUsed();
                                  onClose();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Container(height: 2, color: Colors.white),
          const SizedBox(height: 16),

          // ---------------- FOOTER ----------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ELIGE SABIAMENTE PARA MAXIMIZAR TUS GANANCIAS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'Retro Gaming',
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Añadimos la opción de cerrar disimulada por si el jugador se arrepiente
              GestureDetector(
                onTap: onClose,
                child: const Text(
                  'CERRAR ✕',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontFamily: 'Retro Gaming',
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper para pintar los cuadraditos de las esquinas del diseño
  Widget _buildCorner() {
    return Container(
      width: 4,
      height: 4,
      color: const Color(0xFF6C3FA0),
    );
  }
}

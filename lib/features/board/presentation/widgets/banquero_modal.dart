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
      width: 900,
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            child: const Column(
              children: [
                Text(
                  'HABILIDAD DE BANQUERO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'Retro Gaming',
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  '¿A QUIÉN QUIERES ROBAR?',
                  style: TextStyle(
                    color: Color(0xFFFFEB3B),
                    fontSize: 14,
                    fontFamily: 'Retro Gaming',
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          Container(height: 2, color: Colors.white),

          // ---------------- CONTENIDO ----------------
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: otherPlayers.map((player) {
                final isEscapista =
                    player.characterClass == CharacterClass.escapista;
                final amountToRob = isEscapista ? 1 : 2;
                final canRob = player.coins >= amountToRob;
                
                // Color de botón según el mockup (david/escapista es purpura, otros verde)
                final buttonAsset = isEscapista 
                    ? 'assets/images/ui/btn_morado.png' 
                    : 'assets/images/ui/btn_verde.png';

                return Container(
                  width: 250,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      // Esquinas retro
                      Positioned(top: -2, left: -2, child: _buildCorner()),
                      Positioned(top: -2, right: -2, child: _buildCorner()),
                      Positioned(bottom: -2, left: -2, child: _buildCorner()),
                      Positioned(bottom: -2, right: -2, child: _buildCorner()),
                      
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1435),
                              border: Border.all(color: const Color(0xFF4A3E66), width: 2),
                            ),
                            child: Image.asset(
                              getCharacterImagePath(player.characterClass, true),
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Nombre
                          Text(
                            player.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Retro Gaming',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          // Botón
                          RetroImgButton(
                            label: 'ROBAR $amountToRob¢',
                            asset: buttonAsset,
                            width: 180,
                            height: 45,
                            fontSize: 12,
                            onTap: canRob
                                ? () {
                                    ref.read(webSocketProvider).sendGenericAction({
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
          ),

          // ---------------- FOOTER ----------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Text(
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

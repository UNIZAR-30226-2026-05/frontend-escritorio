import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/game_provider.dart';
import '../../../../auth/presentation/controllers/auth_provider.dart';
import '../../../domain/gamemodels.dart';
import '../../../../../core/widgets/retro_widgets.dart';

class DilemaPrisioneroGame extends ConsumerStatefulWidget {
  final Function(dynamic score) onFinish;
  final Map<String, dynamic> details;

  const DilemaPrisioneroGame({
    super.key,
    required this.onFinish,
    required this.details,
  });

  @override
  ConsumerState<DilemaPrisioneroGame> createState() =>
      _DilemaPrisioneroGameState();
}

class _DilemaPrisioneroGameState extends ConsumerState<DilemaPrisioneroGame> {
  bool _hasVoted = false;

  void _sendVote(String vote) {
    setState(() {
      _hasVoted = true;
    });
    widget.onFinish(vote);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final myUsername = ref.watch(authProvider).username;

    // Identificar al jugador local y al oponente
    final myPlayer = gameState.players.firstWhere(
      (p) => p.username == myUsername,
      orElse: () => gameState.players.isNotEmpty
          ? gameState.players.first
          : Player(
              id: 'dummy',
              username: 'Jugador',
              coins: 0,
              characterClass: CharacterClass.videojugador,
              currentTileIndex: 0),
    );

    // Buscamos a alguien que esté en la misma casilla, si no hay nadie (debug) cogemos a cualquiera que no sea yo.
    final opponent = gameState.players.firstWhere(
      (p) =>
          p.username != myUsername &&
          p.currentTileIndex == myPlayer.currentTileIndex,
      orElse: () => gameState.players.firstWhere(
        (p) => p.username != myUsername,
        orElse: () => myPlayer,
      ),
    );

    // Helper local para los pingüinos grandes (carpeta general)
    String getBigCharacterPath(CharacterClass charClass, bool isFacingRight) {
      final className = charClass.name.toLowerCase();
      final suffix = isFacingRight ? 'der' : 'izq';
      return 'assets/images/characters/general/${className}_frente_$suffix.png';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. FONDO
          Image.asset(
            'assets/images/minigames/dilema/fondo_dilema.png',
            fit: BoxFit.cover,
          ),

          // 2. TÍTULO Y SUBTÍTULO
          const Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: const Column(
              children: [
                Text(
                  '¿COOPERAR O TRAICIONAR?',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 42,
                    color: Color(0xFFFFD700), // Amarillo/Oro
                    shadows: [
                      Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(3, 3)),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'EL DESTINO DE AMBOS ESTÁ EN TUS MANOS',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 16,
                    color: Colors.white70,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // 3. PERSONAJE LOCAL (IZQUIERDA)
          Positioned(
            left: 285, // Más alejado del centro para centrarlo en el foco
            bottom: 105,
            child: SizedBox(
              width: 210 * 1.1,
              height: 310 * 1.1,
              child: Image.asset(
                getBigCharacterPath(myPlayer.characterClass, true),
                fit: BoxFit.contain,
                color: const Color.fromARGB(255, 252, 214, 102)
                    .withValues(alpha: 0.9), // Menos amarillo (más natural)
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),

          // 4. PERSONAJE OPONENTE (DERECHA)
          Positioned(
            right: 285, // Simétrico
            bottom: 105,
            child: SizedBox(
              width: 210 * 1.1,
              height: 310 * 1.1,
              child: Image.asset(
                getBigCharacterPath(opponent.characterClass, false),
                fit: BoxFit.contain,
                color: const Color.fromARGB(255, 252, 214, 102)
                    .withValues(alpha: 0.9), // Menos amarillo
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),

          // 4.5. CARTEL DE RECOMPENSAS (CENTRO)
          if (!_hasVoted)
            Positioned(
              top: 190,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 500,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: const BoxDecoration(
                    color: Colors.black, // Completamente opaco
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TABLA DE PENALIZACIONES',
                        style: TextStyle(
                          fontFamily: 'Retro Gaming',
                          color: Colors.white54, // Color más apagado
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildRuleRow("AMBOS COOPERAN", "+2💰 cada uno",
                          const Color(0xFFFFD700).withValues(alpha: 0.8)),
                      _buildRuleRow("AMBOS TRAICIONAN", "+0💰 cada uno",
                          const Color(0xFFFFD700).withValues(alpha: 0.8)),
                      _buildRuleRow("TÚ TRAICIONAS / ÉL COOPERA", "+3💰 / +0💰",
                          const Color(0xFFFFD700).withValues(alpha: 0.8)),
                      _buildRuleRow("TÚ COOPERAS / ÉL TRAICIONA", "+0💰 / +3💰",
                          const Color(0xFFFFD700).withValues(alpha: 0.8)),
                    ],
                  ),
                ),
              ),
            ),

          // 5. ACCIONES O ESTADO
          if (!_hasVoted)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BOTÓN TRAICIONAR
                  RetroImgButton(
                    label: 'TRAICIONAR',
                    asset: 'assets/images/ui/btn_rojo.png',
                    width: 220 * 1.2,
                    height: 70 * 1.4,
                    fontSize: 20 * 1.2,
                    onTap: () => _sendVote('traicionar'),
                  ),
                  const SizedBox(width: 300), // Botones más alejados
                  // BOTÓN COOPERAR
                  RetroImgButton(
                    label: 'COOPERAR',
                    asset: 'assets/images/ui/btn_verde.png',
                    width: 220 * 1.2,
                    height: 70 * 1.4,
                    fontSize: 20 * 1.2,
                    onTap: () => _sendVote('cooperar'),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purpleAccent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DECISIÓN ENVIADA',
                      style: TextStyle(
                        fontFamily: 'Retro Gaming',
                        color: Colors.purpleAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Esperando al rival...',
                      style: TextStyle(
                        fontFamily: 'Retro Gaming',
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(
                      color: Colors.purpleAccent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String label, String reward, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Retro Gaming',
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            reward,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

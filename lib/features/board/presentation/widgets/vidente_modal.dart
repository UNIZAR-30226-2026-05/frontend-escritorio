import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/retro_widgets.dart';

class VidenteModal extends ConsumerWidget {
  final List<int> diceResults;
  final VoidCallback onClose;

  const VidenteModal({
    super.key,
    required this.diceResults,
    required this.onClose,
  });

  /// Descompone el total en (dadoEspecial, dadoNormal) según el rango.
  /// Rang 1: oro 1-6 + normal 1-6
  /// Rank 2: plata 1-4 + normal 1-6
  /// Rank 3: bronce 1-2 + normal 1-6
  /// Rank 4+: solo normal 1-6 (dadoEspecial = 0)
  (int special, int normal) _splitByRank(int total, int rankIndex) {
    if (rankIndex == 0) {
      // Oro (1-6) + normal (1-6)
      final s = (total / 2).round().clamp(1, 6);
      return (s, (total - s).clamp(1, 6));
    } else if (rankIndex == 1) {
      // Plata (1-4) + normal (1-6)
      final s = (total - 3).clamp(1, 4);
      return (s, total - s);
    } else if (rankIndex == 2) {
      // Bronce (1-2) + normal (1-6)
      final s = (total - 4).clamp(1, 2);
      return (s, total - s);
    } else {
      // Solo dado normal
      return (0, total);
    }
  }

  String _specialSuffix(int rankIndex) {
    if (rankIndex == 0) return 'O';
    if (rankIndex == 1) return 'P';
    if (rankIndex == 2) return 'B';
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 600,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1435),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4A3E66), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---------------- CABECERA ----------------
          const Text(
            'HABILIDAD MÍSTICA',
            style: TextStyle(
              color: Color(0xFFA070FF),
              fontSize: 14,
              fontFamily: 'Retro Gaming',
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'VISIÓN DEL FUTURO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontFamily: 'Retro Gaming',
              letterSpacing: 2.0,
              shadows: [Shadow(color: Colors.white, blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'EL RESULTADO DE LOS DADOS SERÁ:',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Retro Gaming',
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 32),

          // ---------------- LISTA DE RESULTADOS ----------------
          ...List.generate(diceResults.length, (index) {
            final total = diceResults[index];
            final (special, normal) = _splitByRank(total, index);
            final suffix = _specialSuffix(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFF4A3E66), width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        _getRankText(index),
                        style: const TextStyle(
                          color: Color(0xFFA070FF),
                          fontSize: 14,
                          fontFamily: 'Retro Gaming',
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Dado normal (siempre presente)
                          _buildDiceImage(normal, ''),
                          // Dado especial (rank 1-3)
                          if (special > 0) ...[
                            const SizedBox(width: 12),
                            _buildDiceImage(special, suffix),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontFamily: 'Retro Gaming',
                            ),
                          ),
                          Text(
                            '$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'Retro Gaming',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // ---------------- BOTÓN ACEPTAR ----------------
          RetroImgButton(
            label: 'ACEPTAR',
            asset: 'assets/images/ui/btn_morado.png',
            width: 240,
            height: 50,
            fontSize: 16,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildDiceImage(int value, String suffix) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Image.asset(
        'assets/images/board/dados/$value$suffix.png',
        fit: BoxFit.contain,
      ),
    );
  }

  String _getRankText(int index) {
    switch (index) {
      case 0:
        return 'PRIMER PUESTO';
      case 1:
        return 'SEGUNDO PUESTO';
      case 2:
        return 'TERCER PUESTO';
      case 3:
        return 'CUARTO PUESTO';
      default:
        return 'PUESTO ${index + 1}';
    }
  }
}

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
            // rank: 1=oro(O), 2=plata(P), 3=bronce(B), 4=solo dado normal
            final rank = index + 1;

            List<Widget> diceWidgets;
            if (rank == 4) {
              diceWidgets = [_buildDiceFace(total, 4)];
            } else {
              final specialMax = rank == 1 ? 6 : (rank == 2 ? 4 : 2);
              // Descomponemos: die2 ∈ [1, specialMax], die1 ∈ [1, 6], die1+die2=total
              final die2 = _clamp(total - 6, 1, specialMax);
              final die1 = _clamp(total - die2, 1, 6);
              diceWidgets = [
                _buildDiceFace(die1, 4),
                const SizedBox(width: 12),
                _buildDiceFace(die2, rank),
              ];
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4A3E66), width: 2),
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
                        children: diceWidgets,
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

  // Mismos assets que el overlay de dados del tablero.
  // rank: 1=O (oro), 2=P (plata), 3=B (bronce), 4=normal (sin sufijo)
  Widget _buildDiceFace(int value, int rank) {
    String suffix = '';
    if (rank == 1) {
      suffix = 'O';
    } else if (rank == 2) {
      suffix = 'P';
    } else if (rank == 3) {
      suffix = 'B';
    }

    int displayValue = value.clamp(1, 6);
    if (rank == 3 && displayValue > 2) {
      displayValue = (displayValue % 2) + 1;
    } else if (rank == 2 && displayValue > 4) {
      displayValue = (displayValue % 4) + 1;
    }

    return SizedBox(
      width: 56,
      height: 56,
      child: Image.asset(
        'assets/images/board/dados/$displayValue$suffix.png',
        fit: BoxFit.contain,
      ),
    );
  }

  int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
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

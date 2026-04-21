import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/game_provider.dart';
import '../../../../core/widgets/retro_widgets.dart';

class TargetSelectionModal extends ConsumerWidget {
  final String itemName;
  final VoidCallback onClose;
  final Function(String) onTargetSelected;

  const TargetSelectionModal({
    super.key,
    required this.itemName,
    required this.onClose,
    required this.onTargetSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final myUsername = ref.watch(authProvider).username;
    
    // Filtramos los jugadores excluyendo al usuario local
    final otherPlayers = gameState.players
        .where((p) => p.username != myUsername)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
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
            Text(
              'USAR $itemName'.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿A QUIÉN QUIERES PENALIZAR?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 14,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 24),
            // Mapear los otros jugadores a botones de seleccion
            ...otherPlayers.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RetroImgButton(
                    label: p.username.toUpperCase(),
                    asset: 'assets/images/ui/btn_morado.png',
                    width: 200,
                    height: 45,
                    fontSize: 12,
                    onTap: () => onTargetSelected(p.username),
                  ),
                )),
            const SizedBox(height: 16),
            // Boton para cancelar la accion
            RetroImgButton(
              label: 'CANCELAR',
              asset: 'assets/images/ui/btn_rojo.png',
              width: 150,
              height: 40,
              fontSize: 10,
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

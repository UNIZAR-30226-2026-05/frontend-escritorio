import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../board/data/websocket_service.dart';
import '../../domain/shop_models.dart';
import '../../data/shop_repository.dart';
import '../../../board/presentation/controllers/game_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../../core/widgets/retro_widgets.dart';
import '../../../board/presentation/widgets/target_selection_modal.dart';

final shopProvider = Provider<ShopController>((ref) {
  return ShopController(ref);
});

class ShopController {
  final Ref _ref;

  ShopController(this._ref);

  void buyItem(ShopItem item) {
    final payloadBuy = {
      'action': 'comprar_objeto',
      'payload': {'objeto': item.name}
    };

    _ref.read(webSocketProvider).sendGenericAction(payloadBuy);
    debugPrint(" [SHOP] Compra de objeto enviada: ${item.name}");
  }

  void buyAndUseItem(ShopItem item, {String? targetPlayerId}) {
    final payloadBuy = {
      'action': 'comprar_objeto',
      'payload': {'objeto': item.name}
    };

    final actionName = item.name.toLowerCase().contains('salvavidas') ? 'usar_salvavidas' : 'usar_objeto';
    final payloadUse = {
      'action': actionName,
      'payload': {
        'objeto': item.name,
        if (targetPlayerId != null) 'penalizar_a': targetPlayerId
      }
    };

    _ref.read(webSocketProvider).sendGenericAction(payloadBuy);
    _ref.read(webSocketProvider).sendGenericAction(payloadUse);

    debugPrint(" [SHOP] Compra y uso instantáneo enviado: ${item.name}");
  }

  void useItem(String itemName, {String? targetPlayerId}) {
    final actionName = itemName.toLowerCase().contains('salvavidas') ? 'usar_salvavidas' : 'usar_objeto';
    final payload = {
      'action': actionName,
      'payload': {
        'objeto': itemName,
        if (targetPlayerId != null) 'penalizar_a': targetPlayerId
      }
    };

    _ref.read(webSocketProvider).sendGenericAction(payload);
    debugPrint(" [SHOP] Uso de objeto enviado: $payload");
  }
}

class ShopModal extends ConsumerWidget {
  final int playerCoins;
  final VoidCallback onClose;

  const ShopModal({
    super.key,
    required this.playerCoins,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el inventario del jugador activo para los contadores
    final myUsername = ref.watch(authProvider).username;
    final player = ref.watch(gameProvider).players.firstWhere(
          (p) => p.username == myUsername,
          orElse: () => ref.watch(gameProvider).players.first,
        );

    // Ranking: determine if local player is in 1st place
    final gameState = ref.watch(gameProvider);
    final sortedPlayers = gameState.players.toList()
      ..sort((a, b) => b.currentTileIndex.compareTo(a.currentTileIndex));
    final myRank = sortedPlayers.indexWhere((p) => p.username == myUsername) + 1;
    final isFirstPlace = myRank == 1 && myUsername != null;

    return Container(
      width: 900,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        border: Border.all(color: Colors.white, width: 2), // Sin borde redondeado
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
          // HEADER DE LA TIENDA (Todo en una misma fila sobre fondo morado uniforme)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'TIENDA DE OBJETOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 2.0,
                  fontFamily: 'Retro Gaming',
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$playerCoins¢',
                    style: const TextStyle(
                      color: Color(0xFFFFD700), // Amarillo oro para la moneda
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Retro Gaming',
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: onClose,
                    child: const Text(
                      'X',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        fontFamily: 'Retro Gaming',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Línea divisoria blanca fina
          Container(height: 2, color: Colors.white),
          const SizedBox(height: 24),

          // GRID DE OBJETOS (1 Fila Horizontal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ShopRepository.catalog.map((item) {
              final canAfford = playerCoins >= item.price;
              // Calculamos cuántos objetos de este tipo tiene en el inventario
              final itemCount = player.itemInventory
                  .where((i) => i == item.effectType)
                  .length;

              return Container(
                width: 200,
                height: 260, // Altura ajustada
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E), // Mismo fondo morado
                  border: Border.all(color: Colors.white, width: 2), // Borde blanco afilado
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono (Manteniendo tus emojis originales tal y cómo pediste) y contador
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          height: 54,
                          child: Center(
                            child: Image.asset(item.icon, height: 48, filterQuality: FilterQuality.none),
                          ),
                        ),
                        if (itemCount > 0)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEB3B),
                                border:
                                    Border.all(color: Colors.black, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(1, 1),
                                  )
                                ],
                              ),
                              child: Text(
                                'x$itemCount',
                                style: const TextStyle(
                                  fontFamily: 'Retro Gaming',
                                  fontSize: 10,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (isFirstPlace && item.name == 'Mejorar Dados')
                          Positioned.fill(
                            child: Center(
                              child: Transform.rotate(
                                angle: -0.26,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black45, blurRadius: 4)
                                    ],
                                  ),
                                  child: const Text(
                                    'PROHIBIDO',
                                    style: TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Nombre del objeto
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Retro Gaming',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Descripción
                    Expanded(
                      child: Text(
                        item.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontFamily: 'Retro Gaming',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Precio
                    Text(
                      '${item.price}¢',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Retro Gaming',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // BOTÓN DE COMPRA Y USO RETRO
                    RetroImgButton(
                      label: 'Comprar y Usar',
                      asset: 'assets/images/ui/btn_verde.png',
                      width: 140, // tamaño compacto para cuadrar
                      height: 38,
                      fontSize: 8, // Ajustado para que quepa el texto más largo
                      onTap: canAfford
                          ? () {
                              if (item.name == 'Barrera') {
                                // Si es una Barrera, primero pedimos el objetivo
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black87,
                                  builder: (context) => TargetSelectionModal(
                                    itemName: item.name,
                                    onClose: () => Navigator.of(context).pop(),
                                    onTargetSelected: (target) {
                                      ref.read(shopProvider).buyAndUseItem(item, targetPlayerId: target);
                                      Navigator.of(context).pop();
                                      onClose(); // Cerramos la tienda tras el uso exitoso
                                    },
                                  ),
                                );
                              } else {
                                // Para el resto de objetos, compra y uso directo
                                ref.read(shopProvider).buyAndUseItem(item);
                                onClose(); // Cerramos la tienda
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

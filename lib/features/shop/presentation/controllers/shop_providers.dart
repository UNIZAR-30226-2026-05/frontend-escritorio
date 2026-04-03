import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../board/data/websocket_service.dart';
import '../../domain/shop_models.dart';
import '../../data/shop_repository.dart';

final shopProvider = Provider<ShopController>((ref) {
  return ShopController(ref);
});

class ShopController {
  final Ref _ref;

  ShopController(this._ref);

  void buyAndUseItem(ShopItem item, {String? targetPlayerId}) {
    final payloadBuy = {
      'action': 'comprar_objeto',
      'payload': {
        'objeto': item.name 
      }
    };
    
    final payloadUse = {
      'action': 'usar_objeto',
      'payload': {
        'objeto': item.name,
        if (targetPlayerId != null) 'target': targetPlayerId 
      }
    };
    
    _ref.read(webSocketProvider).sendGenericAction(payloadBuy);
    _ref.read(webSocketProvider).sendGenericAction(payloadUse);
    
    print("🛒⚡ [SHOP] Compra y uso instantáneo enviado: ${item.name}");
  }

  void useItem(String itemName) {
    final payload = {
      'action': 'usar_objeto',
      'payload': {
        'objeto': itemName
      }
    };
    
    _ref.read(webSocketProvider).sendGenericAction(payload);
    print("🎒 [SHOP] Uso de objeto enviado: $payload");
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
    return Container(
      width: 520,
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER DE LA TIENDA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF6C3FA0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'TIENDA (USO INMEDIATO)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Monedas actuales del jugador
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '$playerCoins',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // BOTÓN CERRAR
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0x44FFFFFF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text(
                        '✕',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // GRID DE OBJETOS
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ShopRepository.catalog.map((item) {
                final canAfford = playerCoins >= item.price;

                return Container(
                  width: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D2660),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x88FFFFFF), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.icon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.price}¢',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // BOTÓN DE COMPRA/USO
                      GestureDetector(
                        onTap: canAfford
                            ? () {
                                // Llamamos al provider para comprar y usar
                                ref.read(shopProvider).buyAndUseItem(item);
                                // Cerramos la tienda automáticamente tras usar el objeto
                                onClose();
                              }
                            : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: canAfford ? const Color(0xFF2E8B57) : const Color(0xFF555555),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: canAfford ? const Color(0xFF3CB371) : const Color(0xFF777777),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Usar',
                            style: TextStyle(
                              color: canAfford ? Colors.white : const Color(0xFF999999),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
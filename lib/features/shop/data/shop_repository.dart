import '../domain/shop_models.dart';
import '../../board/domain/gamemodels.dart';

class ShopRepository {
  static const List<ShopItem> catalog = [
    ShopItem(
      id: 'item_advance',
      name: 'Avanzar Casillas',
      price: 1, 
      description: 'Suma casillas extra a tu próxima tirada.',
      icon: 'assets/images/items/item_avanzar.png',
      effectType: ItemType.avanzarRetroceder, // TU ENUM
    ),
    ShopItem(
      id: 'item_silver_dice',
      name: 'Mejorar Dados',
      price: 3,
      description: 'Mejora tu segundo dado a un dado de plata (1-4).',
      icon: 'assets/images/items/item_dados.png',
      effectType: ItemType.modificadorDado, // TU ENUM
    ),
    ShopItem(
      id: 'item_block_barrier',
      name: 'Barrera',
      price: 10,
      description: 'Bloquea el turno de un jugador a tu elección.',
      icon: 'assets/images/items/item_barrera.png',
      effectType: ItemType.barrera, // TU ENUM
    ),
    ShopItem(
      id: 'item_lifesaver',
      name: 'Salvavidas bloqueo',
      price: 10,
      description: 'Te libra de una penalización de bloqueo del tablero.',
      icon: 'assets/images/items/item_salvavidas.png',
      effectType: ItemType.salvavidas, // TU ENUM
    ),
  ];

  // Helper para pintar el inventario
  static ShopItem? getItemByType(ItemType type) {
    try {
      return catalog.firstWhere((item) => item.effectType == type);
    } catch (e) {
      return null;
    }
  }

  // Helper para traducir el backend (String) a tu Enum (ItemType)
  static ItemType parseItemType(String backendName) {
    switch (backendName) {
      case 'Avanzar Casillas': return ItemType.avanzarRetroceder;
      case 'Mejorar Dados': return ItemType.modificadorDado;
      case 'Barrera': return ItemType.barrera;
      case 'Salvavidas movimiento': return ItemType.salvavidas;
      case 'Salvavidas bloqueo': return ItemType.salvavidas;
      default: return ItemType.ruleta; // Fallback
    }
  }
}
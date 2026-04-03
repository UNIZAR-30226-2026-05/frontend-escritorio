import '../domain/shop_models.dart';
import '../../board/domain/gamemodels.dart';

class ShopRepository {
  static const List<ShopItem> catalog = [
    ShopItem(
      id: 'item_advance',
      name: 'Avanzar Casillas',
      price: 1, 
      description: 'Suma casillas extra a tu próxima tirada.',
      icon: '👟',
      effectType: ItemType.avanzarRetroceder, // TU ENUM
    ),
    ShopItem(
      id: 'item_silver_dice',
      name: 'Mejorar Dados',
      price: 3,
      description: 'Mejora tu segundo dado a un dado de plata (1-4).',
      icon: '🎲',
      effectType: ItemType.modificadorDado, // TU ENUM
    ),
    ShopItem(
      id: 'item_block_barrier',
      name: 'Barrera',
      price: 10,
      description: 'Bloquea el turno de un jugador a tu elección.',
      icon: '🚧',
      effectType: ItemType.barrera, // TU ENUM
    ),
    ShopItem(
      id: 'item_lifesaver',
      name: 'Salvavidas bloqueo',
      price: 10,
      description: 'Te libra de una penalización de bloqueo del tablero.',
      icon: '🛟',
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
      case 'Avanzar casillas': return ItemType.avanzarRetroceder;
      case 'Mejorar dados': return ItemType.modificadorDado;
      case 'Barreras de bloqueo temporal': return ItemType.barrera;
      case 'Robar monedas': return ItemType.robarMonedas;
      case 'Ruleta': return ItemType.ruleta;
      case 'Quitar turno': return ItemType.quitarTurno;
      case 'Salvavidas': return ItemType.salvavidas;
      default: return ItemType.ruleta; // Fallback
    }
  }
}
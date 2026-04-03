import '../../board/domain/gamemodels.dart'; // Importamos tus enums

class ShopItem {
  final String id;
  final String name;
  final int price;
  final String description;
  final String icon;
  final ItemType effectType; // Usamos tu enum directamente

  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.icon,
    required this.effectType,
  });
}
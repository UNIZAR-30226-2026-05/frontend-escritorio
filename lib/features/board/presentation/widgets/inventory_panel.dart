import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/gamemodels.dart';
import '../../../shop/data/shop_repository.dart';
import '../../../shop/presentation/controllers/shop_providers.dart';

import 'target_selection_modal.dart';

class InventoryPanel extends ConsumerWidget {
  final List<ItemType> items;

  const InventoryPanel({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si el inventario está vacío, no renderizamos nada
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xDD2D1B4E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6C3FA0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabecera del panel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF6C3FA0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: const Text(
              'INVENTARIO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Listado de objetos únicos
          Flexible(
            child: () {
              final uniqueItems = items.toSet().toList();
              return ListView.builder(
                shrinkWrap: true,
                itemCount: uniqueItems.length,
                itemBuilder: (context, index) {
                  final type = uniqueItems[index];
                  // Buscamos los datos visuales (icono/nombre) en el repositorio de la tienda
                  final itemData = ShopRepository.getItemByType(type);

                  if (itemData == null) return const SizedBox.shrink();

                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x33FFFFFF), width: 1),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Image.asset(itemData.icon,
                          height: 20, filterQuality: FilterQuality.none),
                      title: Text(
                        itemData.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              );
            }(),
          ),
        ],
      ),
    );
  }
}

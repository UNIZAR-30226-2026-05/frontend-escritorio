import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/game_provider.dart';
import '../domain/gamemodels.dart';

// Clase de BoardScreen
// Se utiliza un ConsumerWidget porque se usa Riverpod. Este contiene un objeto
// ref dentro del método build
// Este objeto ref conecta la pantalla con el resto de controladores de la aplicación
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar el Estado Global
    // Esta función observa el gameProvider y cada vez que se emita un nuevo estado
    // (tirar un dado por ejemplo), se vuelve a dibujar la pantalla
    final gameState = ref.watch(gameProvider);
    final totalTiles = ref.read(gameProvider.notifier).totalTiles;

    // Obtener el jugador activo usando el ID del turnOrder
    final activePlayerId = gameState.turnOrder[gameState.activePlayerIndex];
    final currentPlayer =
        gameState.players.firstWhere((p) => p.id == activePlayerId);

    return Scaffold(
      appBar: AppBar(title: const Text('Snow Party - Tablero Base')),
      body: Column(
        children: [
          // HUD (Panel superior)
          // Muestra de quién es el turno con el color de su personaje
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            width: double.infinity,
            child: Column(
              children: [
                Text(gameState.serverMessage,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // TODO Añadir la UI de la economía (RF09) y la tienda (RF10).
                // Leer currentPlayer.coins y mostrar un icono de moneda,
                // y un botón flotante para abrir el inventario (currentPlayer.itemInventory).
                Text('Turno de: ${currentPlayer.username}',
                    style: TextStyle(
                        fontSize: 16,
                        color:
                            getCharacterColor(currentPlayer.characterClass))),
              ],
            ),
          ),

          // Tablero
          // Con GridView se crea una cuadrícula de 5 columnas y se dibujan las casillas.
          Expanded(
            // TODO Cambiar el GridView por un Stack dentro de un InteractiveViewer
            // (para que los usuarios hagan zoom y paneo), o integrar el motor gráfico
            // Flame para colocar las casillas para hacer el camino en espiral.
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, // 5 columnas
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: totalTiles,
              itemBuilder: (context, index) {
                // Filtrar qué jugadores están en exactamente esta casilla con índice 'index'
                // Así se sabe cuando hay que dibujarlo
                final playersHere = gameState.players
                    .where((p) => p.currentTileIndex == index)
                    .toList();

                // La casilla (tile) y sus colores y bordes
                return Container(
                  decoration: BoxDecoration(
                    color: index == totalTiles - 1
                        ? Colors.yellow[700]
                        : Colors.white,
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('${index + 1}',
                          style: const TextStyle(
                              color: Colors.black12, fontSize: 24)),

                      // Dibujar las fichas
                      // TODO Cambiar este widget por un AnimatedPositioned
                      // o usar animaciones de interpolación (Tween) para que la ficha
                      // camine casilla por casilla hasta su destino.
                      // El objetivo es que haya cierta animación y no un teletransporte
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: playersHere
                            .map((p) => Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: CircleAvatar(
                                      backgroundColor: getCharacterColor(p
                                          .characterClass), // Usamos la función visual
                                      radius: 10),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Controles (Tirar Dado)
          Padding(
            padding: const EdgeInsets.all(32.0),
            // Botón de tirar el dato con el color del personaje
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor:
                    getCharacterColor(currentPlayer.characterClass),
              ),
              // Función que se activa al presionar y tira el dado (función rollDice())
              // Cuando se presiona se verifica si la partida ha acabado
              onPressed: gameState.currentPhase == GamePhase.finished
                  ? null // Si el juego se ha acabado, el botón se deshabilita
                  : () => ref.read(gameProvider.notifier).rollDice(),
              // Imprime el resultado de tirar el dado con lastDiceResult
              child: Text(
                gameState.lastDiceResult == null
                    ? 'Tirar Dado'
                    : 'Sacaste un ${gameState.lastDiceResult} - Tirar de nuevo',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Función para devolver un color dado un personaje
// TODO Cambiarlo para que devuelva una imagen en vez de un color
Color getCharacterColor(CharacterClass charClass) {
  switch (charClass) {
    case CharacterClass.banquero:
      return Colors.green; // El Banquero es verde
    case CharacterClass.vidente:
      return Colors.purple; // El Místico es morado
    case CharacterClass.escapista:
      return Colors.black; // El Escapista es negro
    case CharacterClass.videojugador:
      return Colors.orange; // El Gamer es naranja
  }
}

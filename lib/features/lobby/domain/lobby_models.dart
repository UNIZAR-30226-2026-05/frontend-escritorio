
// Respuesta del endpoint POST /partidas/crear_partida.
// El backend devuelve el id de la partida recién creada.
class CreatePartidaResponse {
  // Identificador único de la partida creada.
  final String gameId;
  // Constructor de la clase.
  const CreatePartidaResponse({required this.gameId});
  // Constructor alternativo que crea el objeto desde JSON.
  factory CreatePartidaResponse.fromJson(Map<String, dynamic> json) =>
      CreatePartidaResponse(gameId: json['game_id'] as String);
}

// Resumen de una partida devuelta por GET /partidas/
// Se usa para mostrar la lista de partidas disponibles en el lobby.
class PartidaResumen {
  // Identificador único de la partida.
  final String gameId;
  // Estado de la partida: 'WAITING' (esperando jugadores) o 'PLAYING' (en curso).
  final String status;
  // Lista de nombres de jugadores ya conectados a la partida.
  final List<String> playersConnected;
  // Constructor de la clase.
  const PartidaResumen({
    required this.gameId,
    required this.status,
    required this.playersConnected,
  });
  // Constructor alternativo que crea el objeto desde JSON.
  factory PartidaResumen.fromJson(Map<String, dynamic> json) => PartidaResumen(
        gameId: json['game_id'] as String,
        status: json['status'] as String? ?? 'WAITING',
        playersConnected: (json['players_connected'] as List<dynamic>? ?? [])
            .map((p) => p as String)
            .toList(),
      );
}

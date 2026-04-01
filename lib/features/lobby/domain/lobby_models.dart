
// Respuesta del endpoint POST /partidas/crear_partida.
// El backend devuelve el id de la partida recién creada.
class CreatePartidaResponse {
  // Identificador único de la partida creada.
  final String gameId;
  // Constructor de la clase.
  const CreatePartidaResponse({required this.gameId});
  // Constructor alternativo que crea el objeto desde JSON (utilizado en la respuesta del servidor).
  factory CreatePartidaResponse.fromJson(Map<String, dynamic> json) =>
      CreatePartidaResponse(gameId: json['game_id'].toString());
}

// Invitación a una partida recibida a través del WebSocket de sesión.
// Llega con el mensaje 'receive_invite'.
class GameInvite {
  // Nombre del usuario que ha enviado la invitación.
  final String fromUser;
  // Identificador de la partida a la que se invita.
  final String gameId;
  // Constructor de la clase.
  const GameInvite({required this.fromUser, required this.gameId});
  // Constructor alternativo que crea el objeto desde el JSON del WS (utilizado en el mensaje recibido por WebSocket).
  factory GameInvite.fromJson(Map<String, dynamic> json) => GameInvite(
        fromUser: json['from_user'] as String,
        gameId: json['game_id'] as String,
      );
}

// Valores de direcciones para la API
class ApiConstants {
  static const String baseUrl = 'http://localhost:8080';
  static const String wsBaseUrl = 'ws://localhost:8080';

  // Autenticacion
  static const String loginEndpoint = '/usuarios/login';
  static const String registerEndpoint = '/usuarios/registro/';

  // Partidas
  // Listar partidas disponibles en estado WAITING 
  static const String salasEndpoint = '/partidas/';
  // Crear una nueva partida y obtener su game_id 
  static const String crearPartidaEndpoint = '/partidas/crear_partida';

  // WebSocket de partida 
  // Cubre tanto la fase de lobby como la fase de juego 
  static String wsPartidaUrl(String gameId, String token) =>
      '$wsBaseUrl/ws/partida/$gameId?token=$token';

  // WebSocket de sesión 
  // Se abre al iniciar sesión para recibir invitaciones y estado de amigos
  static String wsUsuarioUrl(String username, String token) =>
      '$wsBaseUrl/ws/usuario/$username?token=$token';
}

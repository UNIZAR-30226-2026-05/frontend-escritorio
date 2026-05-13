// Valores de direcciones para la API
class ApiConstants {
  static const String baseUrl = 'https://snowparty.ddns.net';
  static const String wsBaseUrl = 'wss://snowparty.ddns.net';
  //Para jugar en local usar http://localhost:8080 y ws://localhost:8080

  // Autenticacion
  static const String loginEndpoint = '/usuarios/login';
  static const String registerEndpoint = '/usuarios/registro/';
  static const String cambioContrasenaEndpoint = '/usuarios/cambio_contrasena/';

  // Partidas
  // Crear una nueva partida y obtener su game_id
  static const String crearPartidaEndpoint = '/partidas/crear_partida';
  // Unirse a una partida existente por game_id antes de conectar el WS
  static const String unirsePartidaEndpoint = '/partidas/unirse_partida';
  static const String salirPartidaEndpoint = '/partidas/salir_partida';

  // WebSocket de partida
  // Cubre tanto la fase de lobby como la fase de juego
  static String wsPartidaUrl(String gameId, String token) =>
      '$wsBaseUrl/ws/partida/$gameId?token=$token';

  // WebSocket de sesión
  // Se abre al iniciar sesión para recibir invitaciones y estado de amigos
  static String wsUsuarioUrl(String username, String token) =>
      '$wsBaseUrl/ws/usuario/$username?token=$token';
}

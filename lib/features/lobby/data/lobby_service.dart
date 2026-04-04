import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../domain/lobby_models.dart';

// Clase que agrupa las operaciones de comunicacion http del lobby.
class LobbyService {
  // Cabeceras comunes para peticiones autenticadas.
  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // Metodo publico que se llama desde el controlador para crear una partida. 
  // Se encarga de hacer la petición al backend y procesar la respuesta.
  // Crea una nueva partida en el servidor.
  // Devuelve un Future con el game_id de la partida creada.
  Future<CreatePartidaResponse> crearPartida(String token) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.crearPartidaEndpoint}'),headers: _authHeaders(token),);

    // 201 = OK. El backend devuelve el game_id como entero suelto.
    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return CreatePartidaResponse.fromJson({'game_id': decoded});
    // Estatus 401 = Unauthorized.
    } else if (response.statusCode == 401) {
      throw Exception('No autenticado');
    // Cualquier código de error.
    } else {
      throw Exception('Error al crear partida: ${response.statusCode}');
    }
  }

  // Llama al endpoint para unirse a una partida existente antes de conectar el WS.
  // Devuelve void si el servidor acepta al jugador; lanza excepción si no.
  Future<void> unirsePartida(String gameId, String token) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.unirsePartidaEndpoint}'),
      headers: _authHeaders(token),
      body: jsonEncode({'id_partida': int.parse(gameId)}),
    );

    if (response.statusCode == 201) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('No autenticado');
    } else {
      throw Exception('Error al unirse a la partida: ${response.statusCode}');
    }
  }
}

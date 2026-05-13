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

  // Obtiene la lista completa de amigos del usuario (online y offline).
  Future<List<String>> getFriends(String username, String token) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/usuarios/${Uri.encodeComponent(username)}/amigos',
      ),
      headers: _authHeaders(token),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => (e as Map<String, dynamic>)['nombre'].toString())
          .toList();
    }
    return [];
  }

  // Busca usuarios cuyo nombre contenga [query] (mínimo 3 caracteres).
  // Devuelve la lista de nombres coincidentes o lista vacía si no hay resultados.
  Future<List<String>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/usuarios/filtrar_usuarios?cadena=${Uri.encodeComponent(query)}',
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => (e as Map<String, dynamic>)['nombre'].toString())
          .toList();
    }
    if (response.statusCode == 400) return [];
    throw Exception('Error al buscar usuarios: ${response.statusCode}');
  }

  // Elimina la amistad entre dos usuarios.
  Future<bool> removeAmigo(String user1, String user2, String token) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConstants.baseUrl}/usuarios/amigos?user1=${Uri.encodeComponent(user1)}&user2=${Uri.encodeComponent(user2)}',
      ),
      headers: _authHeaders(token),
    );
    return response.statusCode == 200;
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

  // Abandona la partida activa del usuario (limpia sesiones colgadas).
  Future<void> salirPartida(String token) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salirPartidaEndpoint}'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al salir de la partida: ${response.statusCode}');
    }
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../domain/lobby_models.dart';

// Clase que agrupa las operaciones del lobby.
// Solo hay dos: listar partidas disponibles y crear una nueva.
// Unirse a una partida se hace directamente conectando el WebSocket.
class LobbyService {
  // Cabeceras comunes para peticiones autenticadas.
  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // Obtiene la lista de partidas activas.
  // Devuelve un Future con la lista de objetos PartidaResumen.
  Future<List<PartidaResumen>> listarPartidas(String token) async {
    // Realiza una petición GET al endpoint de listar partidas.
    final response = await http.get(Uri.parse('${ApiConstants.baseUrl}${ApiConstants.salasEndpoint}'),
      headers: _authHeaders(token),
    );

    // Estatus 200 = OK.
    if (response.statusCode == 200) {
      // Decodifica la respuesta JSON y mapea cada elemento a un objeto PartidaResumen.
      final List<dynamic> lista = jsonDecode(response.body) as List<dynamic>;
      return lista.map((p) => PartidaResumen.fromJson(p as Map<String, dynamic>)).toList();
    // Cualquier código de error.
    } else {
      throw Exception('Error al obtener partidas: ${response.statusCode}');
    }
  }

  // Crea una nueva partida en el servidor.
  // Devuelve un Future con el game_id de la partida creada.
  Future<CreatePartidaResponse> crearPartida(String token) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.crearPartidaEndpoint}'),headers: _authHeaders(token),);

    // 201 = OK.
    if (response.statusCode == 201) {
      return CreatePartidaResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    // Estatus 401 = Unauthorized.
    } else if (response.statusCode == 401) {
      throw Exception('No autenticado');
    // Cualquier código de error.
    } else {
      throw Exception('Error al crear partida: ${response.statusCode}');
    }
  }
}

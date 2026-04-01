import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../domain/lobby_models.dart';

// Clase que agrupa las operaciones de comunicacion http del lobby.
// Unirse a una partida se hace conectando el WebSocket con el game_id
// recibido por invitación a través del WebSocket de sesión.
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

    // 200 o 201 = OK. El backend puede devolver el game_id como entero suelto
    // o como objeto JSON: ambos casos se normalizan a String en fromJson.
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final Map<String, dynamic> json = decoded is Map<String, dynamic>
          ? decoded
          : {'game_id': decoded};
      return CreatePartidaResponse.fromJson(json);
    // Estatus 401 = Unauthorized.
    } else if (response.statusCode == 401) {
      throw Exception('No autenticado');
    // Cualquier código de error.
    } else {
      throw Exception('Error al crear partida: ${response.statusCode}');
    }
  }
}

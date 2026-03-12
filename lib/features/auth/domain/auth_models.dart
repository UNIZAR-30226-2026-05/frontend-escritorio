/// Datos que se envían al endpoint de registro
class RegisterRequest {
  final String nombre;
  final String password;

  const RegisterRequest({required this.nombre, required this.password});

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'password': password,
      };
}

/// Respuesta del endpoint de login
class AuthResponse {
  final String accessToken;
  final String tokenType;

  const AuthResponse({required this.accessToken, required this.tokenType});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String,
      );
}

/// Sesión guardada localmente (token + nombre de usuario)
class UserSession {
  final String token;
  final String username;

  const UserSession({required this.token, required this.username});
}

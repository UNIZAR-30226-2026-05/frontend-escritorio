import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'controllers/auth_provider.dart';
import '../../../core/widgets/retro_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _usernameError;
  String? _passwordError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _usernameError = _usernameController.text.trim().isEmpty ? 'Campo requerido' : null;
      _passwordError = _passwordController.text.isEmpty ? 'Campo requerido' : null;
    });
    if (_usernameError != null || _passwordError != null) return;
    await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final fw = size.width * 0.30;
    final fh = size.height * 0.08;
    final titleSize = size.height * 0.075;
    final labelSize = size.height * 0.022;
    final inputSize = size.height * 0.020;
    final gap = size.height * 0.025;
    final linkSize = size.height * 0.018;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inicia sesión\npara jugar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: titleSize,
                color: const Color(0xFF1a1a2e),
                height: 1.4,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 16),
                  Shadow(color: Colors.white, blurRadius: 8),
                ],
              ),
            ),
            SizedBox(height: gap * 1.8),
            RetroField(
              label: 'Nombre de usuario',
              controller: _usernameController,
              focusNode: _usernameFocus,
              fieldWidth: fw,
              fieldHeight: fh,
              labelFontSize: labelSize,
              inputFontSize: inputSize,
              errorText: _usernameError,
              textInputAction: TextInputAction.next,
              onSubmitted: () => _passwordFocus.requestFocus(),
            ),
            SizedBox(height: gap),
            RetroField(
              label: 'Contraseña',
              controller: _passwordController,
              focusNode: _passwordFocus,
              fieldWidth: fw,
              fieldHeight: fh,
              labelFontSize: labelSize,
              inputFontSize: inputSize,
              obscureText: true,
              errorText: _passwordError,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            if (authState.error != null) ...[
              SizedBox(height: gap * 0.5),
              Text(
                authState.error!,
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Retro Gaming',
                  fontSize: labelSize * 0.85,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: gap * 1.4),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: linkSize,
                  color: const Color(0xFF1a1a2e),
                ),
                children: [
                  const TextSpan(text: 'Si no tienes cuenta,\nregístrate '),
                  TextSpan(
                    text: 'AQUI',
                    style: const TextStyle(
                      color: Color(0xFF6B21A8),
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.go('/register'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

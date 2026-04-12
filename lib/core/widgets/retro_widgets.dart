import 'package:flutter/material.dart';

// Widget reutilizable que representa un campo de texto con estilo retro.
// Se usan tanto LoginScreen como RegisterScreen para mantener un aspecto uniforme.
// Recibe los parámetros de tamaño desde la pantalla padre, que los calcula
// proporcionalmente al tamaño de la ventana con MediaQuery, de modo que
// el campo se adapta correctamente al tamaño de la ventana.
class RetroField extends StatelessWidget {
  // Texto que aparece encima del campo indicando qué debe escribir el usuario.
  final String label;
  // Controlador que permite leer y modificar el texto escrito en el campo.
  final TextEditingController controller;
  // Si es true, el texto escrito se oculta con puntos (para contraseñas).
  final bool obscureText;
  // Mensaje de error que se muestra debajo del campo cuando la validación falla.
  // Si es null no se muestra nada.
  final String? errorText;
  // Nodo de foco que permite cambiar el foco a este campo desde otro widget
  // (por ejemplo, al pulsar Enter en el campo anterior).
  final FocusNode? focusNode;
  // Acción que muestra el teclado virtual al pulsar Enter:
  //   - TextInputAction.next - mueve el foco al siguiente campo
  //   - TextInputAction.done - cierra el teclado y ejecuta onSubmitted
  final TextInputAction textInputAction;
  // Callback que se ejecuta cuando el usuario pulsa Enter en este campo.
  // En campos intermedios se usa para mover el foco; en el último, para enviar el formulario.
  final VoidCallback? onSubmitted;
  // Ancho del campo en píxeles, calculado por la pantalla padre
  // como un porcentaje del ancho de la ventana .
  final double fieldWidth;
  // Alto del campo en píxeles, calculado por la pantalla padre
  // como un porcentaje del alto de la ventana.
  final double fieldHeight;
  // Tamaño de fuente para la etiqueta superior, proporcional al alto de ventana.
  final double labelFontSize;
  // Tamaño de fuente para el texto escrito dentro del campo, proporcional al alto de ventana.
  final double inputFontSize;

  // Constructor que requiere los parámetros esenciales para configurar el campo de texto.  
  const RetroField({
    super.key,
    required this.label,
    required this.controller,
    required this.fieldWidth,
    required this.fieldHeight,
    required this.labelFontSize,
    required this.inputFontSize,
    this.obscureText = false,
    this.errorText,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // Texto que identifica el campo
        // Las sombras blancas generan el efecto de brillo retro que
        // rodea las letras.
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: labelFontSize,
            color: const Color(0xFF1a1a2e),
            shadows: const [
              Shadow(color: Colors.white, blurRadius: 10), // halo exterior
              Shadow(color: Colors.white70, blurRadius: 4), // halo interior
            ],
          ),
        ),

        // Separación proporcional entre etiqueta y campo.
        SizedBox(height: fieldHeight * 0.15),

        // Contenedor de tamaño fijo que usa rellenable.png como fondo de la ui.
        // BoxFit.fill estira la imagen para que ocupe exactamente
        // el ancho y el alto del contenedor, independientemente de su tamaño original.
        Container(
          width: fieldWidth,
          height: fieldHeight,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ui/rellenable.png'),
              fit: BoxFit.fill,
            ),
          ),
          // Center coloca el TextField justo en el centro vertical del contenedor.
          // Esto, combinado con isCollapsed = true, evita que el cursor quede
          // desalineado respecto a la imagen de fondo.
          child: Center(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              textInputAction: textInputAction,
              // Al pulsar Enter se invoca el callback proporcionado por la pantalla padre.
              onSubmitted: (_) => onSubmitted?.call(),
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: inputFontSize,
                // HARDCODEADO YA QUE SE USA UN FONDO BLANCO AHORA
                // Color oscuro para que el texto sea legible sobre la imagen de fondo.
                color: const Color(0xFF1a1a2e),
              ),
              // Color del cursor de escritura, en morado para mantener la estética.
              cursorColor: const Color(0xFF6B21A8),
              decoration: InputDecoration(
                // Sin borde visible: la imagen de fondo ya actúa como borde decorativo.
                border: InputBorder.none,
                // isCollapsed permite que el Center situe al TextField exactamente 
                //en el centro del Container, sin añadir padding extra.
                isCollapsed: true,
                // Solo padding horizontal para separar el texto de los bordes laterales.
                contentPadding: EdgeInsets.symmetric(
                  horizontal: fieldWidth * 0.06,
                ),
              ),
            ),
          ),
        ),

        // Solo se muestra si la pantalla padre ha detectado un error de validación.
        if (errorText != null)
          Padding(
            padding: EdgeInsets.only(top: fieldHeight * 0.12),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Retro Gaming',
                fontSize: labelFontSize * 0.8,
              ),
            ),
          ),
      ],
    );
  }
}

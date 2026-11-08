/// Política de privacidad de SaludAMG (texto en la app).
abstract final class PrivacyContent {
  static const String version = '1.3';
  static const String versionDate = '2026-11-08';
  static const String responsable = 'Alberto Maestre Gutiérrez';
  static const String emailContacto = 'info@albertomaestre.es';
  static const String web = 'https://www.albertomaestre.es/';
  static const String appName = 'SaludAMG';

  /// Identificador enviado al panel al aceptar (APP_AUTH).
  static const String acceptanceVersion = '$version-$versionDate';

  static const String title = 'Política de privacidad';
  static const String subtitle =
      'Información sobre el tratamiento de datos personales (RGPD / LOPDGDD)';

  /// Resumen de lo que cambia respecto a la versión anterior (se muestra al
  /// pedir de nuevo la aceptación a quien ya tenía la sesión abierta).
  static const String cambios =
      '• Tus datos de salud se guardan cifrados en el teléfono y separados por '
      'cuenta AMG.\n'
      '• No se incluyen en la copia automática del sistema (Google).\n'
      '• La app comprueba de vez en cuando con el panel que tu cuenta sigue '
      'activa (solo se envían tu usuario y la app).';

  static String get fullText => '''
Política de privacidad de $appName
Versión $version · $versionDate

1. Responsable del tratamiento
El responsable del tratamiento es $responsable, persona física, en relación con la aplicación $appName.
Contacto: $emailContacto
Sitio web: $web

2. Ámbito
$appName es una aplicación de seguimiento personal de salud (tensión arterial, pulso, peso, glucosa, oxigenación, pasos, medicación y recordatorios). No sustituye el criterio de un profesional sanitario.
Está dirigida a personas adultas (mayores de 18 años).

3. Qué se queda en tu dispositivo
Estos datos se almacenan solo en tu teléfono, cifrados, y no se envían al panel por el solo hecho de usar la app:
• Perfiles y mediciones (tensión, pulso, peso, etc.).
• Medicación, tomas (con la hora prevista y la hora real), stock y preferencias de avisos.
• Recordatorios, importaciones de Health Connect / Apple Health (si las usas) y ajustes de bloqueo con PIN o huella.
• Copias de seguridad e informes que exportes o importes (tú eliges el destino del archivo).
• Aceptación de esta política y de las condiciones de uso (versión y fecha).
Si varias personas usan $appName en el mismo teléfono, los datos de cada cuenta AMG se guardan por separado y cada una solo ve los suyos.
Estos datos no se incluyen en la copia de seguridad automática del sistema (p. ej. Google). Para conservarlos fuera del teléfono usa «Exportar copia».
Los archivos temporales que se crean al compartir una copia o un informe se borran solos del teléfono a los pocos minutos.

4. Qué se envía al servidor (cuenta AMG)
Si configuras la conexión con el panel AMG, al registrarte o iniciar sesión pueden tratarse:
• Usuario, contraseña (almacenada cifrada/hash en el servidor), y email, que se usa para recuperar la contraseña.
• Identificador técnico de dispositivo, plataforma, versión de la app y build.
• App solicitada ($appName), estado de la cuenta (pendiente / activa) y sesiones.
• Comprobación periódica de la cuenta: con la sesión abierta y conexión a internet, la app pregunta al panel, como mucho cada 12 horas, si tu cuenta sigue activa y con acceso a $appName. Solo se envían tu usuario y el nombre de la app.
No se envían al panel tus mediciones, medicación ni historial clínico en ningún momento.

5. Finalidades
• Permitir el uso local de $appName en tu dispositivo.
• Gestionar el alta de cuenta, la aprobación por el administrador y el acceso a la app.
• Comprobar que la cuenta sigue activa y cerrar la sesión en el teléfono si el administrador la bloquea o retira el acceso.
• Soporte técnico y control de instalaciones/dispositivos.
• Comprobar actualizaciones de la app (metadata de versión), sin enviar tu historial de salud.

6. Base jurídica
• Ejecución del servicio / medidas precontractuales asociadas a la cuenta y a la prestación de la app (art. 6.1.b RGPD).
• Consentimiento al aceptar esta política (art. 6.1.a RGPD).
• Interés legítimo en seguridad técnica y prevención de abusos (art. 6.1.f RGPD), cuando proceda.

7. Conservación
• Datos en el dispositivo: mientras uses la app o hasta que los borres (desinstalación, borrado de datos o restauración). Cerrar la sesión no los borra: siguen cifrados en el teléfono para cuando vuelvas a entrar con la misma cuenta.
• Cuenta e instalación en servidor: mientras la cuenta esté activa o sea necesario para soporte y seguridad, y después según plazos legales.

8. Destinatarios
No se venden datos personales con fines comerciales.
Pueden acceder proveedores de alojamiento del panel/API (habitualmente en la UE) como encargados cuando corresponda, y autoridades si hay obligación legal.
$appName no utiliza publicidad personalizada ni redes de anuncios.

9. Health Connect / Apple Health
Si autorizas la sincronización con la plataforma de salud del sistema, $appName leerá solo los tipos de dato que permitas. El tratamiento adicional lo rigen también las políticas de Google / Apple. Puedes revocar permisos en el sistema.

10. Derechos
Puedes ejercer acceso, rectificación, supresión, oposición, limitación y, cuando proceda, portabilidad, así como retirar el consentimiento.
Escribe a $emailContacto. También puedes reclamar ante la AEPD (www.aepd.es).
Los datos que solo están en tu teléfono (mediciones, medicación…) no los tiene el responsable: puedes consultarlos, exportarlos o borrarlos tú desde la app o desinstalándola.

11. Seguridad
Se aplican medidas razonables, entre ellas:
• Datos de salud cifrados (AES) en el teléfono, con la clave en el almacén seguro del sistema.
• Sesión de la cuenta guardada en el almacén seguro del sistema.
• HTTPS hacia el panel y contraseñas guardadas con hash en el servidor.
• Bloqueo opcional con huella o PIN, con límite de intentos.
• Copias de seguridad exportadas con contraseña: cifradas y con sello para detectar modificaciones.
Ningún sistema es 100 % seguro: protege el teléfono y guarda en un lugar seguro las copias que exportes, sobre todo si son sin contraseña.

12. Menores
$appName está dirigida solo a adultos. No se autoriza el registro de menores de 18 años.

13. Cambios
Esta política puede actualizarse. La versión vigente en la app es $version ($versionDate). Si hay cambios relevantes, se pedirá una nueva aceptación.
''';
}

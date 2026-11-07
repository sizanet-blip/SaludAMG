/// Política de privacidad de SaludAMG (texto en la app).
abstract final class PrivacyContent {
  static const String version = '1.1';
  static const String versionDate = '2026-10-28';
  static const String responsable = 'Alberto Maestre Gutiérrez';
  static const String emailContacto = 'info@albertomaestre.es';
  static const String web = 'https://www.albertomaestre.es/';
  static const String appName = 'SaludAMG';

  /// Identificador enviado al panel al aceptar (APP_AUTH).
  static const String acceptanceVersion = '$version-$versionDate';

  static const String title = 'Política de privacidad';
  static const String subtitle =
      'Información sobre el tratamiento de datos personales (RGPD / LOPDGDD)';

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
Estos datos se almacenan de forma local y no se envían al panel por el solo hecho de usar la app:
• Perfiles y mediciones (tensión, pulso, peso, etc.).
• Medicación, tomas, stock y preferencias de avisos.
• Recordatorios, importaciones de Health Connect / Apple Health (si las usas) y ajustes de bloqueo PIN/biometría.
• Copias de seguridad que exportes o importes (tú eliges el destino del archivo).
• Aceptación de esta política y de las condiciones de uso (versión y fecha).

4. Qué se envía al servidor (cuenta AMG)
Si configuras la conexión con el panel AMG, al registrarte o iniciar sesión pueden tratarse:
• Usuario, contraseña (almacenada cifrada/hash en el servidor), email opcional y código de recuperación.
• Identificador técnico de dispositivo, plataforma, versión de la app y build.
• App solicitada ($appName), estado de la cuenta (pendiente / activa) y sesiones.
No se envían al panel tus mediciones, medicación ni historial clínico como parte del registro de cuenta.

5. Finalidades
• Permitir el uso local de $appName en tu dispositivo.
• Gestionar el alta de cuenta, la aprobación por el administrador y el acceso a la app.
• Soporte técnico y control de instalaciones/dispositivos.
• Comprobar actualizaciones de la app (metadata de versión), sin enviar tu historial de salud.

6. Base jurídica
• Ejecución del servicio / medidas precontractuales asociadas a la cuenta y a la prestación de la app (art. 6.1.b RGPD).
• Consentimiento al aceptar esta política (art. 6.1.a RGPD).
• Interés legítimo en seguridad técnica y prevención de abusos (art. 6.1.f RGPD), cuando proceda.

7. Conservación
• Datos en el dispositivo: mientras uses la app o hasta que los borres (desinstalación, borrado de datos o restauración).
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

11. Seguridad
Se aplican medidas razonables (p. ej. HTTPS hacia el panel, hash de contraseñas, bloqueo local opcional). Ningún sistema es 100 % seguro: protege el dispositivo y las copias de seguridad exportadas.

12. Menores
$appName está dirigida solo a adultos. No se autoriza el registro de menores de 18 años.

13. Cambios
Esta política puede actualizarse. La versión vigente en la app es $version ($versionDate). Si hay cambios relevantes, se pedirá una nueva aceptación.
''';
}

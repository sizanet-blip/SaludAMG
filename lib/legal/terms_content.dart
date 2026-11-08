/// Condiciones de uso de SaludAMG (texto en la app).
abstract final class TermsContent {
  static const String version = '1.2';
  static const String versionDate = '2026-11-07';
  static const String responsable = 'Alberto Maestre Gutiérrez';
  static const String emailContacto = 'info@albertomaestre.es';
  static const String appName = 'SaludAMG';

  static const String acceptanceVersion = '$version-$versionDate';

  static const String title = 'Condiciones de uso';
  static const String subtitle = 'Limitación de responsabilidad y uso bajo tu cargo';

  static const String resumenCorto =
      '$appName se ofrece “tal cual”, sin garantía de ausencia de errores. '
      'No sustituye consejo médico. Úsala bajo tu responsabilidad.';

  static String get fullText => '''
Condiciones de uso de $appName
Versión $version · $versionDate

1. Aceptación
Al usar $appName aceptas estas condiciones. Si no estás de acuerdo, no utilices la aplicación.
Titular: $responsable. Contacto: $emailContacto

2. Naturaleza del servicio
$appName es una herramienta de seguimiento personal de salud y medicación. No es un dispositivo médico certificado ni sustituye diagnóstico, tratamiento o consejo de un profesional sanitario.
Los avisos de medicación o recordatorios son ayudas; tú eres responsable de seguir las indicaciones de tu médico o farmacéutico.

3. Cuenta y acceso
El acceso puede requerir una cuenta AMG. La solicitud puede quedar pendiente hasta la aprobación del administrador. Eres responsable de custodiar tu usuario y contraseña y de indicar un email al que tengas acceso, porque es la vía para recuperar la contraseña.

4. Uso bajo tu responsabilidad
Utilizas la app bajo tu exclusiva responsabilidad. Debes contrastar cualquier dato (mediciones importadas, gráficas, exportaciones) antes de basar en ellos decisiones sanitarias.

5. Software “tal cual”
El software se facilita “tal cual” y “según disponibilidad”, sin garantía de ausencia de errores, disponibilidad continua, exactitud o idoneidad para un fin concreto.

6. Limitación de responsabilidad
En la máxima medida permitida por la ley, $responsable no se hace responsable de:
• Fallos, errores o interrupciones de la app o del panel.
• Pérdida o corrupción de datos (historial, backups, configuración).
• Resultados incorrectos o incompletos (incluida la sincronización con Health Connect / Apple Health).
• Daños derivados del uso o de la imposibilidad de uso.
• Decisiones sanitarias tomadas a partir de la información mostrada en la app.

7. Servicio
Si, pese a lo anterior, resultara alguna responsabilidad legalmente ineludible y el servicio es gratuito para ti, esa responsabilidad quedará limitada, en la medida permitida por la ley, a cero euros (0 €), salvo cuando la ley lo prohíba (p. ej. dolo o negligencia grave no limitable).

8. Cambios
Estas condiciones pueden actualizarse. Versión en la app: $version ($versionDate). Tras cambios relevantes se pedirá una nueva aceptación cuando proceda.
''';
}

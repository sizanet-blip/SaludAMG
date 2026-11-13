// Contenido de ayuda de SaludAMG (guía, manual y FAQ).
// El HTML para el CMS vive en docs/manual-web-cms.html.

class HelpDocSection {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;

  const HelpDocSection({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

class HelpDoc {
  final String id;
  final String title;
  final String subtitle;
  final List<HelpDocSection> sections;

  const HelpDoc({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sections,
  });
}

class HelpFaqItem {
  final String question;
  final String answer;

  const HelpFaqItem({required this.question, required this.answer});
}

abstract final class HelpContent {
  static const String supportEmail = 'info@albertomaestre.es';
  static const String appName = 'SaludAMG';

  static const HelpDoc guiaRapida = HelpDoc(
    id: 'guia',
    title: 'Guía rápida de uso',
    subtitle: 'Lo esencial para empezar en pocos minutos',
    sections: [
      HelpDocSection(
        title: '1. Qué es SaludAMG',
        paragraphs: [
          '$appName es una app de seguimiento personal: tensión arterial, pulso, peso, glucosa, oxigenación, pasos, medicación y recordatorios.',
          'No sustituye el criterio de un profesional sanitario. Los avisos de medicación son ayudas; tú decides cómo seguir las indicaciones de tu médico.',
        ],
      ),
      HelpDocSection(
        title: '2. Cuenta AMG',
        bullets: [
          'Entras con tu cuenta AMG: la misma para todas las apps AMG.',
          'Primera vez: Crear cuenta con usuario, contraseña (mínimo 6) y email repetido; acepta privacidad y condiciones.',
          'Si ya tienes cuenta de otra app AMG, entra con ella y envía la solicitud al panel.',
          'El administrador aprueba el acceso. Si olvidas la contraseña, te enviamos un enlace a tu email.',
        ],
      ),
      HelpDocSection(
        title: '3. Primeros pasos',
        bullets: [
          'Inicio → Configuración → Ficha: completa tu perfil.',
          'Configuración → Datos a medir: elige qué métricas registrar.',
          'En el inicio, pulsa Medición para anotar la primera lectura.',
          'Opcional: Medicaciones, Recordatorios (en Configuración), Health Connect / Apple Health, bloqueo PIN.',
        ],
      ),
      HelpDocSection(
        title: '4. Día a día',
        bullets: [
          'Inicio: accesos rápidos Medicación y Medición, más Resumen, Historial, Medicaciones, Configuración y Ayuda.',
          'Resumen: última toma, evolución y exportar Excel/PDF.',
          'Historial: icono de ajustes (tune) para filtrar por periodo, momento, origen o aviso.',
          'Configuración → Copia de seguridad: exporta o restaura un archivo cifrado.',
        ],
      ),
      HelpDocSection(
        title: '5. Consejos express',
        bullets: [
          'Haz copias de seguridad con frecuencia.',
          'Si usas PIN/biometría, no olvides el código.',
          'Privacidad y condiciones están en Ayuda y en Acerca de (Configuración).',
          'Soporte: $supportEmail.',
        ],
      ),
    ],
  );

  static const HelpDoc manualCompleto = HelpDoc(
    id: 'manual',
    title: 'Manual completo',
    subtitle: 'Referencia detallada para el día a día',
    sections: [
      HelpDocSection(
        title: '1. Introducción',
        paragraphs: [
          '$appName guarda tus datos en el dispositivo. El panel AMG solo recibe datos de cuenta/instalación si el build está configurado (usuario, versión, device); no se envían mediciones ni medicación al registrarte.',
          'La app está pensada para adultos. Úsala bajo tu responsabilidad y contrasta los datos antes de decisiones sanitarias.',
        ],
      ),
      HelpDocSection(
        title: '2. Cuenta AMG y acceso',
        paragraphs: [
          'Para usar $appName necesitas una cuenta AMG. Es la misma para SaludAMG, TiroAMG, MotoAMG y Simulador 112: si ya tienes una, no crees otra.',
        ],
        bullets: [
          'Primera vez: Crear cuenta con usuario, contraseña (mínimo 6 caracteres) y tu email dos veces. El email es obligatorio: sirve para recuperar la contraseña.',
          'Acepta la política de privacidad y las condiciones y pulsa «Crear y solicitar acceso».',
          'Cuenta de otra app AMG: entra con tu usuario y contraseña, acepta las condiciones y pulsa «Enviar solicitud al panel».',
          'El administrador aprueba cada solicitud. Mientras tanto verás «Pendiente de aprobación».',
          'Contraseña olvidada: pulsa «Olvidé mi contraseña» y abre el enlace que te llegará al email.',
          'En Acerca de (Configuración) ves la versión y el ID de dispositivo.',
        ],
      ),
      HelpDocSection(
        title: '3. Pantalla de inicio',
        paragraphs: [
          'La pantalla principal muestra el logotipo de SaludAMG y los botones de acción Medicación y Medición (el de medicación se puede ocultar en preferencias).',
          'Debajo tienes el menú principal: Resumen, Historial, Medicaciones, Configuración y Ayuda. Cerrar sesión aparece si hay cuenta AMG.',
        ],
      ),
      HelpDocSection(
        title: '4. Resumen',
        paragraphs: [
          'Última medición, gráfica de evolución (periodo y métrica con el icono de ajustes) y acceso al historial.',
          'Desde el menú de la cabecera de Resumen puedes Exportar Excel o Exportar PDF.',
        ],
      ),
      HelpDocSection(
        title: '5. Menú principal y Configuración',
        bullets: [
          'Resumen — última toma, evolución e informes.',
          'Historial — listado; filtros con el icono tune de la cabecera.',
          'Medicaciones — tratamientos, tomas del día y preferencias (tune).',
          'Configuración → Ficha, Recordatorios, Datos a medir, Opciones de medicación.',
          'Configuración → Copia de seguridad, Bloqueo, Cuenta AMG, Acerca de.',
          'Ayuda — guía, manual, FAQ y textos legales.',
        ],
      ),
      HelpDocSection(
        title: '6. Mediciones',
        paragraphs: [
          'Al pulsar Medición eliges fecha/hora y los valores habilitados (tensión, pulso, peso, glucosa, SpO₂, pasos, notas…).',
          'Puedes editar una lectura desde el historial o desde la tarjeta de la última medición en Resumen.',
        ],
      ),
      HelpDocSection(
        title: '7. Medicación y recordatorios',
        paragraphs: [
          'Medicaciones tiene tres vistas: Hoy (marcar tomas), Lista (altas y edición) y Cumplimiento (7 y 30 días). El icono tune abre las opciones.',
          'En Hoy cada fila es una toma: hora, nombre y dosis. El icono de verificación es Tomado y el de menos es Omitir. La hora se pone verde si está tomada y naranja si está omitida.',
          'Tomado pide fecha y hora (atajo Ahora). Puedes retroceder hasta 30 días: si ese día le toca, la marca se casa con el horario previsto. Omitir pide el día. Si ya estaba marcada, el diálogo incluye Quitar marca.',
          'En Lista, Añadir horario abre el reloj y no hay un máximo de horas; una hora no se puede repetir. El menú de cada medicación abre Tomas, con las marcas de los últimos 30 días, para borrar un error.',
          'En Opciones de medicación defines el botón en inicio, el seguimiento de dosis, el stock y los avisos de pedida al médico.',
          'Recordatorios (en Configuración) y notificaciones locales del sistema.',
        ],
      ),
      HelpDocSection(
        title: '8. Importación de salud',
        paragraphs: [
          'Si autorizas Health Connect (Android) o Apple Health (iOS), la app puede leer solo los tipos que permitas.',
          'Revisa Datos a medir y los permisos del sistema. Puedes revocar el acceso en los ajustes del dispositivo.',
        ],
      ),
      HelpDocSection(
        title: '9. Exportación y copia de seguridad',
        bullets: [
          'Resumen o Historial → Exportar Excel / PDF: informes para compartir o archivar (no sustituyen la historia clínica).',
          'Configuración → Copia de seguridad: archivo cifrado; al importar sustituye los datos actuales — exporta antes si quieres conservar lo de ahora.',
        ],
      ),
      HelpDocSection(
        title: '10. Bloqueo con huella o PIN',
        paragraphs: [
          'Al iniciar sesión, si el teléfono tiene huella o cara registrada, $appName te ofrece usarla para abrir la app. También se activa en Configuración → Bloqueo, con huella, con PIN o con las dos.',
          'Si la huella falla, pulsa «Entrar con la contraseña de la cuenta». Si olvidas el PIN, pulsa «¿Olvidaste el PIN?» y escribe la contraseña de tu cuenta AMG: se quita el PIN y puedes poner otro. Ambas opciones necesitan internet.',
          'Tras 5 PIN incorrectos hay que esperar unos segundos antes de volver a probar.',
        ],
      ),
      HelpDocSection(
        title: '11. Actualizaciones y soporte',
        paragraphs: [
          'Configuración → Acerca de → Buscar actualizaciones. Según el build, abre el canal propio o Google Play.',
          'Soporte: $supportEmail. Indica versión de la app y, si puedes, capturas.',
        ],
      ),
      HelpDocSection(
        title: '12. Privacidad y condiciones',
        paragraphs: [
          'Los textos legales propios de $appName están en Ayuda y en Acerca de. Al registrarte debes aceptarlos.',
          'Detalle del tratamiento (qué queda en el dispositivo y qué va al panel) en la Política de privacidad.',
        ],
      ),
    ],
  );

  static const List<HelpFaqItem> faq = [
    HelpFaqItem(
      question: '¿SaludAMG sustituye al médico?',
      answer:
          'No. Es una herramienta de seguimiento personal. Contrasta siempre con un profesional sanitario.',
    ),
    HelpFaqItem(
      question: '¿Por qué me pide cuenta al abrir?',
      answer:
          'Tus datos se guardan en el móvil, pero el acceso necesita tu cuenta AMG aprobada por el administrador. Es la misma cuenta para todas las apps AMG.',
    ),
    HelpFaqItem(
      question: 'Me he registrado y no puedo entrar',
      answer:
          'El administrador tiene que aprobar tu acceso a $appName. Cuando lo active, inicia sesión con tu usuario y contraseña.',
    ),
    HelpFaqItem(
      question: 'Olvidé la contraseña',
      answer:
          'Pulsa «Olvidé mi contraseña» en la pantalla de acceso y escribe tu email: recibirás un enlace para crear una nueva.',
    ),
    HelpFaqItem(
      question: '¿Se envían mis mediciones al servidor?',
      answer:
          'No como parte del registro de cuenta. Las mediciones y la medicación se guardan en el dispositivo. El panel puede recibir datos de instalación/cuenta (versión, device, usuario). Detalle en Política de privacidad.',
    ),
    HelpFaqItem(
      question: '¿Dónde están Medicación y Medición?',
      answer:
          'En la pantalla de inicio, arriba del menú. Medición abre el formulario de una lectura; Medicación abre el listado (se puede ocultar en Medicación config → Botón en inicio).',
    ),
    HelpFaqItem(
      question: 'Se me olvidó marcar una toma de hace unos días',
      answer:
          'En Medicaciones → Hoy pulsa el icono de tomado, cambia la fecha (hasta 30 días) y la hora, y guarda. Si ese día tenía horario, cuenta para ese día. Las de ayer también aparecen en el bloque Ayer.',
    ),
    HelpFaqItem(
      question: 'He marcado una toma dos veces o en el día que no era',
      answer:
          'Abre otra vez Tomado u Omitir y pulsa Quitar marca. O entra en Lista, menú de la medicación, Tomas, y borra esa fila.',
    ),
    HelpFaqItem(
      question: '¿Cuántos horarios puedo poner?',
      answer:
          'Los que necesites. En el formulario de la medicación, Añadir horario abre el reloj. La misma hora no se puede repetir.',
    ),
    HelpFaqItem(
      question: '¿Dónde están los recordatorios?',
      answer:
          'Inicio → Configuración → Recordatorios. Ahí gestionas avisos de medicación y mediciones.',
    ),
    HelpFaqItem(
      question: '¿Cómo filtro el historial?',
      answer:
          'En Historial, pulsa el icono de ajustes (tune) en la cabecera. Ahí eliges periodo, momento, origen y avisos.',
    ),
    HelpFaqItem(
      question: '¿Cómo exporto para mi médico?',
      answer:
          'Entra en Resumen y usa Exportar Excel o Exportar PDF en el menú de la cabecera. Elige periodo y bloques del informe.',
    ),
    HelpFaqItem(
      question: '¿Cómo restauro una copia?',
      answer:
          'Configuración → Copia de seguridad → Importar. Sustituye los datos actuales; exporta antes si quieres conservar lo de ahora.',
    ),
    HelpFaqItem(
      question: 'No llegan los recordatorios',
      answer:
          'Comprueba permisos de notificación del sistema, que el recordatorio esté activo y que el modo No molestar no silencie la app.',
    ),
    HelpFaqItem(
      question: '¿Qué es «Datos a medir»?',
      answer:
          'Configuración → Datos a medir. Define qué campos aparecen al anotar una medición. Desactiva lo que no uses.',
    ),
    HelpFaqItem(
      question: 'Health Connect / Apple Health no sincroniza',
      answer:
          'Revisa permisos en el sistema y qué tipos de dato autorizaste. La app solo lee lo que permitas.',
    ),
    HelpFaqItem(
      question: '¿Dónde están privacidad y condiciones?',
      answer:
          'Inicio → Ayuda, o Configuración → Acerca de → Legal. Debes aceptarlas al crear la cuenta AMG.',
    ),
    HelpFaqItem(
      question: '¿Dónde pido ayuda personalizada?',
      answer:
          'Escribe a $supportEmail con la versión de la app y una descripción del problema.',
    ),
  ];
}

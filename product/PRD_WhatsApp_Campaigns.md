# Product Requirements Document (PRD): Campañas de WhatsApp

**1. Introducción**

*   **Funcionalidad:** Campañas proactivas basadas en plantillas a través de WhatsApp.
*   **Problema:** Los usuarios de Chatwoot no pueden iniciar conversaciones con sus clientes en WhatsApp, uno de los canales de comunicación más importantes del mundo. Esto representa una gran brecha funcional y limita severamente los casos de uso de marketing, notificaciones y re-engagement.
*   **Objetivo:** Permitir a los administradores enviar mensajes de plantilla (pre-aprobados por Meta) a audiencias de contactos segmentadas, desbloqueando así un canal de comunicación vital y de alto impacto.

**2. User Stories**

*   **Como Administrador,** quiero poder crear una campaña "one-off" seleccionando una de mis plantillas de WhatsApp aprobadas, para poder enviar notificaciones y mensajes de marketing que cumplan con las políticas de Meta.
*   **Como Administrador,** quiero poder seleccionar una audiencia para mi campaña basada en etiquetas de contacto, para poder enviar mensajes relevantes al grupo correcto de usuarios.
*   **Como Administrador,** quiero poder rellenar las variables de la plantilla (ej. nombre del cliente, número de pedido) antes de enviar la campaña, para poder personalizar la comunicación a escala.
*   **Como Administrador,** quiero poder programar la campaña para una fecha y hora futuras, para poder planificar mis actividades de comunicación con antelación.

**3. Requisitos**

*   **Flujo de Creación de Campaña (UI/UX):**
    *   Al crear una campaña "One-off", si se selecciona un inbox de WhatsApp, el formulario debe cambiar dinámicamente.
    *   El campo de mensaje de texto libre debe ser reemplazado por un selector desplegable de "Plantillas de WhatsApp".
    *   Este selector debe poblarse con las plantillas disponibles para el inbox seleccionado.
    *   Al seleccionar una plantilla, deben aparecer dinámicamente campos de texto para cada una de sus variables (ej. `{{1}}`, `{{2}}`).
    *   Se debe mostrar una vista previa simple del mensaje con las variables rellenas.
*   **Backend:**
    *   El modelo `Campaign` debe soportar el tipo de inbox `Whatsapp`.
    *   Un nuevo servicio (`Whatsapp::OneoffWhatsappCampaignService`) debe orquestar el envío masivo.
    *   El servicio debe iterar sobre la audiencia y poner en cola trabajos individuales para enviar el mensaje de plantilla a cada contacto.
*   **Fuera del Alcance (MVP):**
    *   Analíticas avanzadas (tasas de entrega, lectura, etc.).
    *   Pruebas A/B.
    *   Constructor de audiencias complejo (más allá de las etiquetas).

**4. Métricas de Éxito**

*   **Adopción:** Nº de campañas de WhatsApp creadas por semana.
*   **Uso:** Nº de mensajes enviados a través de campañas de WhatsApp.
*   **Feedback Cualitativo:** Opiniones de los usuarios sobre la facilidad de uso y el valor aportado. 
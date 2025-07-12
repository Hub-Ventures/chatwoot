# Product Requirements Document (PRD): Campañas de WhatsApp

**Estado del Proyecto:** 🟢 **Completo y Production-Ready** - Sistema técnicamente completo con UX perfecta. Previsualización de mensajes implementada. Funcionalidad crítica de importación masiva agregada.

**1. Introducción**

*   **Funcionalidad:** Campañas proactivas basadas en plantillas a través de WhatsApp.
*   **Problema:** Los usuarios de Chatwoot no pueden iniciar conversaciones con sus clientes en WhatsApp, uno de los canales de comunicación más importantes del mundo. Esto representa una gran brecha funcional y limita severamente los casos de uso de marketing, notificaciones y re-engagement.
*   **Objetivo:** Permitir a los administradores enviar mensajes de plantilla (pre-aprobados por Meta) a audiencias de contactos segmentadas, desbloqueando así un canal de comunicación vital y de alto impacto.

**2. User Stories**

### **✅ Completadas:**
*   **Como Administrador,** quiero poder crear una campaña "one-off" seleccionando una de mis plantillas de WhatsApp aprobadas, para poder enviar notificaciones y mensajes de marketing que cumplan con las políticas de Meta.
*   **Como Administrador,** quiero poder seleccionar una audiencia para mi campaña basada en etiquetas de contacto, para poder enviar mensajes relevantes al grupo correcto de usuarios.
*   **Como Administrador,** quiero poder programar la campaña para una fecha y hora futuras, para poder planificar mis actividades de comunicación con antelación.
*   **Como Administrador,** quiero poder rellenar las variables de la plantilla (ej. nombre del cliente, número de pedido) **Y VER UNA PREVISUALIZACIÓN en tiempo real** antes de enviar la campaña, para poder personalizar la comunicación a escala **con confianza de que el mensaje se ve correcto**.
*   **Como Administrador,** quiero ver una previsualización en tiempo real del mensaje final mientras relleno los parámetros, para asegurarme de que el texto se ve correcto antes del envío.
*   **Como Administrador,** quiero recibir validación visual si faltan parámetros obligatorios, para evitar enviar mensajes incompletos o rotos.
*   **Como Administrador,** quiero ver el formato del mensaje similar a como aparecería en WhatsApp, para tener una representación fiel del resultado final.
*   **Como Administrador,** quiero importar contactos masivamente y automáticamente asociarlos a múltiples canales, para que estén inmediatamente disponibles para campañas sin trabajo manual adicional.

**3. Requisitos**

### **✅ Completados (Julio 2025):**

*   **Flujo de Creación de Campaña (UI/UX):**
    *   ✅ Al crear una campaña "One-off", si se selecciona un inbox de WhatsApp, el formulario cambia dinámicamente.
    *   ✅ El campo de mensaje de texto libre es reemplazado por un selector desplegable de "Plantillas de WhatsApp".
    *   ✅ El selector se pobla con las plantillas disponibles para el inbox seleccionado.
    *   ✅ Al seleccionar una plantilla, aparecen dinámicamente campos de texto para cada variable (ej. `{{1}}`, `{{2}}`).
    *   ✅ Vista previa del mensaje con las variables rellenas en tiempo real.
    *   ✅ Validación visual de parámetros obligatorios con indicadores de error.
    *   ✅ Formato visual similar a WhatsApp con header verde y estilo apropiado.

*   **Backend:**
    *   ✅ El modelo `Campaign` soporta el tipo de inbox `Whatsapp`.
    *   ✅ Servicio `Whatsapp::OneoffWhatsappCampaignService` implementado y funcional.
    *   ✅ El servicio itera sobre la audiencia y envía mensajes de plantilla a cada contacto.
    *   ✅ Integración exitosa con WhatsApp Cloud API.
    *   ✅ Creación automática de conversaciones para campañas.
    *   ✅ Seguimiento de estado de campañas (Programado → Completado).

### **✅ Nuevos Requisitos Implementados:**

*   **Previsualización y Validación (UI/UX):**
    *   ✅ Componente de previsualización en tiempo real del mensaje final
    *   ✅ Procesamiento visual de parámetros `{{1}}`, `{{2}}`, etc. en tiempo real
    *   ✅ Validación de campos obligatorios con indicadores visuales
    *   ✅ Advertencias si faltan parámetros requeridos antes del envío
    *   ✅ Formateo visual similar al aspecto de WhatsApp real
    *   ✅ Actualización instantánea de la vista previa al cambiar parámetros

*   **Lógica de Validación (Backend/Frontend):**
    *   ✅ Validación de que todos los parámetros requeridos estén llenos
    *   ✅ Prevención de envío de campañas con parámetros faltantes
    *   ✅ Manejo de errores cuando los parámetros no coinciden con la plantilla

*   **Bulk Contact Import with Channel Association:**
    *   ✅ Interfaz para seleccionar múltiples canales durante importación masiva
    *   ✅ Asociación automática de contactos a canales seleccionados
    *   ✅ Soporte para canales API, Email, WhatsApp, SMS y TwilioSms
    *   ✅ Generación inteligente de source_ids por tipo de canal
    *   ✅ Validación de ownership de canales por cuenta
    *   ✅ Procesamiento eficiente con manejo de duplicados
    *   ✅ UX completa con botones de selección masiva

**4. Métricas de Éxito**

### **✅ Métricas Actuales (Sistema Robusto):**
*   **Adopción:** Nº de campañas de WhatsApp creadas por semana.
*   **Uso:** Nº de mensajes enviados a través de campañas de WhatsApp.
*   **Funcionalidad:** Tasa de éxito de envío de campañas (actualmente 100% técnico).
*   **Confiabilidad:** Tasa de campañas completadas sin errores críticos (>99% esperado).
*   **Performance:** Tiempo promedio de procesamiento por lote de 100 contactos.
*   **Límites:** Nº de campañas que alcanzan límite de 10K contactos.
*   **Errores:** Distribución de tipos de errores (validación, DB, comunicación).
*   **Retry:** Tasa de éxito de reintentos automáticos para errores transitorios.

### **🎯 Métricas Objetivo (Sistema Completo):**
*   **Confianza del Usuario:** % de campañas enviadas sin modificaciones después de ver la previsualización.
*   **Reducción de Errores:** % de reducción en campañas con parámetros incorrectos o faltantes.
*   **Satisfacción UX:** Puntuación de satisfacción del usuario con la experiencia de creación de campañas.
*   **Feedback Cualitativo:** Opiniones de los usuarios sobre la facilidad de uso y el valor aportado.
*   **Adopción de Importación:** % de importaciones masivas que incluyen asociación a canales.
*   **Eficiencia Operativa:** Tiempo ahorrado en configuración manual vs. importación automatizada.
*   **Disponibilidad de Contactos:** % de contactos importados inmediatamente disponibles para campañas.

---

## **5. Estado Actual del Proyecto**

### **✅ Lo que Funciona:**
- **Funcionalidad Técnica Completa:** Las campañas se crean, programan y envían exitosamente
- **Integración WhatsApp:** Conectado correctamente con WhatsApp Cloud API  
- **Selector de Plantillas:** Carga y muestra plantillas disponibles dinámicamente
- **Campos de Parámetros:** Genera automáticamente campos para `{{1}}`, `{{2}}`, etc.
- **Previsualización en Tiempo Real:** Muestra el mensaje final con estilo WhatsApp
- **Validación Visual:** Indicadores de error para parámetros faltantes
- **Segmentación:** Selección de audiencia por etiquetas funcional
- **Programación:** Fechas y horas de envío futuras operativas
- **Importación Masiva:** Contactos automáticamente asociados a canales múltiples

### **🔒 Mejoras de Robustez Implementadas (Julio 2025):**
- **Validaciones Exhaustivas:** Sistema previene campañas con datos faltantes o inválidos
- **Ejecución Asíncrona:** Campañas no bloquean el servidor durante envío masivo
- **Límites de Seguridad:** Máximo 10,000 contactos por campaña con timeout de 30 minutos
- **Manejo de Errores Granular:** Errores específicos por tipo (DB, comunicación, validación)
- **Prevención de Concurrencia:** Evita ejecución duplicada de campañas completadas
- **Circuit Breaker:** Detiene campaña si hay demasiados errores consecutivos
- **Retry Inteligente:** Reintentos específicos para errores transitorios de DB
- **Procesamiento por Lotes:** Envío en batches de 100 contactos para optimizar performance

### **✅ Gaps UX Resueltos:**
- **Previsualización Completa:** Los usuarios ven el mensaje final antes del envío
- **Validación Visual:** Indicadores claros para parámetros faltantes u obligatorios
- **Confianza Total:** Los usuarios pueden verificar que el texto se ve correcto
- **Importación Eficiente:** Contactos automáticamente disponibles para campañas

### **✅ Gaps Técnicos Resueltos:**
- **Robustez:** Sistema ahora maneja errores, límites y validaciones exhaustivamente
- **Escalabilidad:** Implementado procesamiento asíncrono y por lotes
- **Confiabilidad:** Prevención de concurrencia y retry inteligente implementados
- **Seguridad:** Validaciones y límites para prevenir uso inadecuado

---

## **6. Próximos Pasos - Expansión del Sistema**

### **✅ Completado:** 
- **P1.5: Previsualización de Mensajes** - Experiencia de usuario perfecta implementada
- **P1.7: Bulk Contact Import** - Importación masiva con asociación automática a canales

### **🎯 Próximas Prioridades:**
- **P2: Campañas de Email** - Completar la expansión de canales fundamentales
- **P3: Analíticas de Campaña v1** - Métricas básicas y seguimiento de rendimiento
- **P4: Gestor de Audiencias Reutilizables** - Segmentos guardados y reutilizables

### **📋 Fuera del Alcance (Versión Actual):**
*   Analíticas avanzadas (tasas de entrega, lectura, etc.).
*   Pruebas A/B.
*   Constructor de audiencias complejo (más allá de las etiquetas).
*   Plantillas con imágenes o botones interactivos.

---

*Última actualización: Julio 11, 2025*  
*Estado: 🟢 Sistema Completo y Production-Ready - UX perfecta con importación masiva implementada* 
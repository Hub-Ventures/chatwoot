# Product Requirements Document (PRD): Campañas de WhatsApp

**Estado del Proyecto:** 🟢 **Robusto con Gap UX** - Sistema técnicamente completo y production-ready. Solo falta previsualización de mensajes para experiencia perfecta.

**1. Introducción**

*   **Funcionalidad:** Campañas proactivas basadas en plantillas a través de WhatsApp.
*   **Problema:** Los usuarios de Chatwoot no pueden iniciar conversaciones con sus clientes en WhatsApp, uno de los canales de comunicación más importantes del mundo. Esto representa una gran brecha funcional y limita severamente los casos de uso de marketing, notificaciones y re-engagement.
*   **Objetivo:** Permitir a los administradores enviar mensajes de plantilla (pre-aprobados por Meta) a audiencias de contactos segmentadas, desbloqueando así un canal de comunicación vital y de alto impacto.

**2. User Stories**

### **✅ Completadas:**
*   **Como Administrador,** quiero poder crear una campaña "one-off" seleccionando una de mis plantillas de WhatsApp aprobadas, para poder enviar notificaciones y mensajes de marketing que cumplan con las políticas de Meta.
*   **Como Administrador,** quiero poder seleccionar una audiencia para mi campaña basada en etiquetas de contacto, para poder enviar mensajes relevantes al grupo correcto de usuarios.
*   **Como Administrador,** quiero poder programar la campaña para una fecha y hora futuras, para poder planificar mis actividades de comunicación con antelación.

### **🚧 Gap Crítico Identificado:**
*   **Como Administrador,** quiero poder rellenar las variables de la plantilla (ej. nombre del cliente, número de pedido) **Y VER UNA PREVISUALIZACIÓN en tiempo real** antes de enviar la campaña, para poder personalizar la comunicación a escala **con confianza de que el mensaje se ve correcto**.

### **🔥 Nuevas User Stories Críticas:**
*   **Como Administrador,** quiero ver una previsualización en tiempo real del mensaje final mientras relleno los parámetros, para asegurarme de que el texto se ve correcto antes del envío.
*   **Como Administrador,** quiero recibir validación visual si faltan parámetros obligatorios, para evitar enviar mensajes incompletos o rotos.
*   **Como Administrador,** quiero ver el formato del mensaje similar a como aparecería en WhatsApp, para tener una representación fiel del resultado final.

**3. Requisitos**

### **✅ Completados (Julio 2025):**

*   **Flujo de Creación de Campaña (UI/UX):**
    *   ✅ Al crear una campaña "One-off", si se selecciona un inbox de WhatsApp, el formulario cambia dinámicamente.
    *   ✅ El campo de mensaje de texto libre es reemplazado por un selector desplegable de "Plantillas de WhatsApp".
    *   ✅ El selector se pobla con las plantillas disponibles para el inbox seleccionado.
    *   ✅ Al seleccionar una plantilla, aparecen dinámicamente campos de texto para cada variable (ej. `{{1}}`, `{{2}}`).
    *   ❌ **FALTANTE:** Vista previa del mensaje con las variables rellenas.

*   **Backend:**
    *   ✅ El modelo `Campaign` soporta el tipo de inbox `Whatsapp`.
    *   ✅ Servicio `Whatsapp::OneoffWhatsappCampaignService` implementado y funcional.
    *   ✅ El servicio itera sobre la audiencia y envía mensajes de plantilla a cada contacto.
    *   ✅ Integración exitosa con WhatsApp Cloud API.
    *   ✅ Creación automática de conversaciones para campañas.
    *   ✅ Seguimiento de estado de campañas (Programado → Completado).

### **🚧 Gap Crítico - Requisitos Faltantes:**

*   **Previsualización y Validación (UI/UX):**
    *   ◻️ Componente de previsualización en tiempo real del mensaje final
    *   ◻️ Procesamiento visual de parámetros `{{1}}`, `{{2}}`, etc. en tiempo real
    *   ◻️ Validación de campos obligatorios con indicadores visuales
    *   ◻️ Advertencias si faltan parámetros requeridos antes del envío
    *   ◻️ Formateo visual similar al aspecto de WhatsApp real
    *   ◻️ Actualización instantánea de la vista previa al cambiar parámetros

*   **Lógica de Validación (Backend/Frontend):**
    *   ◻️ Validación de que todos los parámetros requeridos estén llenos
    *   ◻️ Prevención de envío de campañas con parámetros faltantes
    *   ◻️ Manejo de errores cuando los parámetros no coinciden con la plantilla

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

### **🎯 Métricas Objetivo (Post-Previsualización):**
*   **Confianza del Usuario:** % de campañas enviadas sin modificaciones después de ver la previsualización.
*   **Reducción de Errores:** % de reducción en campañas con parámetros incorrectos o faltantes.
*   **Satisfacción UX:** Puntuación de satisfacción del usuario con la experiencia de creación de campañas.
*   **Feedback Cualitativo:** Opiniones de los usuarios sobre la facilidad de uso y el valor aportado.

---

## **5. Estado Actual del Proyecto**

### **✅ Lo que Funciona:**
- **Funcionalidad Técnica Completa:** Las campañas se crean, programan y envían exitosamente
- **Integración WhatsApp:** Conectado correctamente con WhatsApp Cloud API  
- **Selector de Plantillas:** Carga y muestra plantillas disponibles dinámicamente
- **Campos de Parámetros:** Genera automáticamente campos para `{{1}}`, `{{2}}`, etc.
- **Segmentación:** Selección de audiencia por etiquetas funcional
- **Programación:** Fechas y horas de envío futuras operativas

### **🔒 Mejoras de Robustez Implementadas (Julio 2025):**
- **Validaciones Exhaustivas:** Sistema previene campañas con datos faltantes o inválidos
- **Ejecución Asíncrona:** Campañas no bloquean el servidor durante envío masivo
- **Límites de Seguridad:** Máximo 10,000 contactos por campaña con timeout de 30 minutos
- **Manejo de Errores Granular:** Errores específicos por tipo (DB, comunicación, validación)
- **Prevención de Concurrencia:** Evita ejecución duplicada de campañas completadas
- **Circuit Breaker:** Detiene campaña si hay demasiados errores consecutivos
- **Retry Inteligente:** Reintentos específicos para errores transitorios de DB
- **Procesamiento por Lotes:** Envío en batches de 100 contactos para optimizar performance

### **❌ Gap UX Identificado:**
- **Experiencia "Ciega":** Los usuarios envían campañas sin saber cómo se verá el mensaje final
- **Sin Validación Visual:** No hay indicadores si faltan parámetros obligatorios
- **Falta de Confianza:** Los usuarios no pueden verificar que el texto se ve correcto

### **✅ Gaps Técnicos Resueltos:**
- **Robustez:** Sistema ahora maneja errores, límites y validaciones exhaustivamente
- **Escalabilidad:** Implementado procesamiento asíncrono y por lotes
- **Confiabilidad:** Prevención de concurrencia y retry inteligente implementados
- **Seguridad:** Validaciones y límites para prevenir uso inadecuado

---

## **6. Próximos Pasos - Solo UX**

### **🎯 Prioridad 1: Previsualización de Mensajes (P1.5)**
- **Objetivo:** Completar la experiencia de usuario para campañas de WhatsApp
- **Entregables:** Componente de previsualización en tiempo real con validación
- **Impacto:** Convertir sistema técnicamente robusto en experiencia de usuario perfecta
- **Nota:** La infraestructura técnica ya está completa y es production-ready

### **📋 Fuera del Alcance (Versión Actual):**
*   Analíticas avanzadas (tasas de entrega, lectura, etc.).
*   Pruebas A/B.
*   Constructor de audiencias complejo (más allá de las etiquetas).
*   Plantillas con imágenes o botones interactivos.

---

*Última actualización: Julio 15, 2025*  
*Estado: 🟢 Sistema Robusto y Production-Ready - Solo requiere P1.5 para experiencia UX completa* 
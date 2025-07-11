# Roadmap de Producto: Evolución de Campañas

**Visión:** Transformar "Campañas" de una utilidad básica a un motor de comunicación omnicanal inteligente y basado en datos.

---

### **Fase 1: Expansión de Canales Fundamentales (Enfoque Actual)**

*Objetivo: Cerrar las brechas funcionales más grandes y llevar las campañas a los canales que los usuarios más demandan.*

*   **P1: Campañas de WhatsApp (MVP)**
    *   **Estado:** ✅ Completado
    *   **Descripción:** Permitir el envío de campañas "one-off" usando plantillas de WhatsApp pre-aprobadas.
    *   **Hitos Clave:**
        *   ✅ Modificar modelo `Campaign` para aceptar inboxes de WhatsApp.
        *   ✅ Crear esqueleto del servicio `Whatsapp::OneoffWhatsappCampaignService`.
        *   ✅ Adaptar UI para diferenciar formulario de SMS y WhatsApp.
        *   ✅ Implementar selector de plantillas y campos de variables en la UI.
        *   ✅ Implementar la lógica de envío masivo en el servicio del backend.
        *   ✅ Corregir manejo de template_info y parámetros en el backend.
        *   ✅ Implementar creación automática de conversaciones para campañas.
    *   **Funcionalidades Implementadas:**
        *   📧 Formulario completo para campañas de WhatsApp con selector de plantillas
        *   🎯 Segmentación de audiencia por etiquetas
        *   ⏰ Programación de envío con fecha y hora específica
        *   📱 Soporte para plantillas con parámetros dinámicos
        *   ✉️ Envío masivo exitoso con WhatsApp Cloud API
        *   📊 Seguimiento de estado de campañas (Programado → Completado)
    *   **Dependencias:** Ninguna.
    *   **Fecha de Finalización:** Julio 2025

*   **P2: Campañas de Email (MVP)**
    *   **Estado:** ⏳ Pendiente
    *   **Descripción:** Permitir el envío de campañas "one-off" a través de inboxes de Email. Incluirá campo de "asunto" y gestión de enlaces para darse de baja.
    *   **Dependencias:** Ninguna.

---

### **Fase 2: Robustecimiento y Medición**

*Objetivo: Dar a los usuarios las herramientas para entender qué funciona y optimizar sus campañas, haciendo la funcionalidad más "inteligente".*

*   **P3: Analíticas de Campaña v1**
    *   **Estado:** ⏳ Pendiente
    *   **Descripción:** Añadir métricas básicas a cada campaña: mensajes enviados, fallidos, y conversaciones generadas. Mostrar estas métricas en la UI de campañas.
    *   **Dependencias:** Fase 1 completada.

*   **P4: Gestor de Audiencias Reutilizables v1**
    *   **Estado:** ⏳ Pendiente
    *   **Descripción:** Permitir a los usuarios crear, guardar y nombrar segmentos de audiencia basados en etiquetas para no tener que seleccionarlas manualmente cada vez.
    *   **Dependencias:** Ninguna.

*   **P5: Vista Previa de Mensajes**
    *   **Estado:** ⏳ Pendiente
    *   **Descripción:** En el formulario de creación, mostrar una previsualización en tiempo real de cómo se verá el mensaje en el canal seleccionado (widget web, SMS, WhatsApp).
    *   **Dependencias:** Fase 1 completada.

---

### **Fase 3: Optimización y Escalamiento**

*Objetivo: Introducir funcionalidades avanzadas para equipos de marketing y ventas que buscan optimizar su comunicación a gran escala.*

*   **P6: Pruebas A/B para Campañas**
    *   **Estado:** ⏳ Pendiente
    *   **Descripción:** Permitir crear dos versiones de un mensaje de campaña (A/B), enviarlas a subconjuntos de la audiencia y medir cuál tiene mejor rendimiento.
    *   **Dependencias:** Fase 2 (Analíticas) completada.

*   **P7: Analíticas de Campaña v2**
    *   **Estado:** ⏳ Pendiente
    *   **Descripción:** Añadir métricas más avanzadas, como tasa de apertura (si es posible), tasa de clics en enlaces y un panel de comparación entre campañas.
    *   **Dependencias:** Fase 2 (Analíticas) completada. 

---

## **Resumen de Progreso**

### **Estadísticas Generales:**
- **Total de Features:** 7
- **Completadas:** 1 ✅
- **En Progreso:** 0 🚧  
- **Pendientes:** 6 ⏳

### **Hitos Recientes:**
- **Julio 2025:** ✅ **Campañas de WhatsApp completadas**
  - Implementación completa del formulario con selector de plantillas
  - Integración exitosa con WhatsApp Cloud API
  - Sistema de programación y envío masivo funcional
  - Seguimiento de estado de campañas operativo

### **Próximos Pasos:**
1. **P2: Campañas de Email** - Próxima prioridad para completar la Fase 1
2. **P3: Analíticas de Campaña v1** - Fundamental para empezar la Fase 2

---

*Última actualización: Julio 10, 2025* 
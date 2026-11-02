# Informe de auditoría integral — RestaurantApp

**Fecha:** 2 de noviembre de 2026  
**Fase:** diagnóstico previo a implementación  
**Alcance revisado:** aplicación Flutter, backend Spring Boot, contratos visibles, configuración, documentación y pruebas automatizadas.

> Esta fase no modifica código ni configuración. El informe se basa en inspección estática y pruebas automatizadas locales; no equivale a una certificación de seguridad ni a una prueba en producción.

## 1. Diagnóstico ejecutivo

**Estado general: NO PREPARADA PARA PRODUCCIÓN.** La aplicación ya contiene flujos funcionales de autenticación, catálogo, carrito, pedidos, Checkout de Stripe y operaciones administrativas. Sin embargo, existen riesgos bloqueantes de autorización y gestión de secretos, además de funcionalidades que se presentan en pantalla pero están vacías, simuladas o no conectadas.

Los bloqueos prioritarios son:

1. El registro público confía en el rol enviado por el cliente y lo incorpora al token de sesión.
2. Hay secretos de infraestructura y un secreto de firma JWT dentro del código/configuración del backend. Además, el inicio de sesión imprime la contraseña en consola.
3. Las rutas administrativas y analíticas no verifican de forma consistente que el usuario sea propietario del restaurante o del recurso consultado.
4. La aplicación no llega a mostrar la interfaz si falla la carga inicial del backend.
5. El panel de IA, recompensas, notificaciones y varias acciones visibles no ofrecen el flujo anunciado.
6. La suite Flutter termina con **5 fallos**; el backend sí supera sus **9 pruebas**.

No asigno un porcentaje de completitud: no existe un inventario aprobado de requisitos con denominador verificable, y la guía de auditoría prohíbe estimar porcentajes sin evidencia. La calificación por módulo y los límites de verificación aparecen abajo.

## 2. Alcance y método

- Se inventariaron **46 archivos Dart de producción**, **152 archivos Java de producción**, **23 controladores REST** y los recursos de configuración identificados en el repositorio.
- Se contrastaron la composición real de Flutter y los repositorios Spring Boot con `README.md`, `DESIGN.md` y `DOCUMENTO_DISENO_SOLUCION_MOVIL.md`.
- Se ejecutaron `flutter test`, `flutter analyze` y `mvnw.cmd test`.
- No se conectó a una base de datos MySQL real, una cuenta Stripe, un webhook público ni un dispositivo móvil físico. Por ello, ningún flujo de pago real, despliegue, biometría nativa o autorización entre cuentas se considera validado en ejecución.
- Se revisó comportamiento representado en código y pruebas, pero no se completó una inspección manual de accesibilidad con lector de pantalla ni pruebas de usabilidad con usuarios.

## 3. Inventario funcional observado

| Módulo | Estado | Evidencia y observación | Qué falta |
|---|---|---|---|
| Registro e inicio de sesión | **PARCIAL** | Flutter llama a Spring Boot y presenta rutas diferenciadas por rol. El servidor permite que el registro envíe el rol. | Restringir el rol en backend, probar el flujo contra servicio real, conectar recuperación de contraseña y corregir mensajes de error. |
| Sesión y biometría | **PARCIAL** | Existe persistencia de token y acceso biométrico. El token usa `SharedPreferences`; la opción biométrica de la pantalla de datos del cliente guarda una contraseña vacía. | Almacenamiento seguro del token, recuperación de sesión al iniciar y una única ruta biométrica que conserve credenciales válidas. |
| Catálogo y categorías | **PARCIAL** | El catálogo y las categorías se solicitan a Spring Boot; el cliente filtra por búsqueda/categoría. | Carga con estados de error/vacío/reintento, validar selección del restaurante y verificar todo contra backend disponible. |
| Carrito | **PARCIAL** | El carrito persiste localmente y contempla personalización y deduplicación del checkout. | Confirmar persistencia ante actualización de catálogo/cambio de cuenta y presentar estados de guardado/sincronización. |
| Checkout y pago | **PARCIAL** | El backend recalcula precios, crea sesiones Stripe y confirma por webhook; hay pruebas de idempotencia y firma. | Prueba integral con credenciales Stripe de prueba y webhook accesible; documentar cancelación/recuperación y validar configuración de producción. |
| Historial y estado de pedidos | **PARCIAL** | Hay endpoints de historial/estado y consulta periódica del pago. | Validar contra servicio real; añadir acciones de cancelación o explicar claramente que no están disponibles; cubrir transiciones y estados terminales. |
| Operación de pedidos (administrador) | **PARCIAL** | Se muestran pedidos pagados y se envían cambios de estado al backend. | Verificar propiedad del restaurante en cada operación y validar transiciones permitidas en servidor. |
| Menú/inventario (administrador) | **PARCIAL** | CRUD de productos, disponibilidad y carga de imágenes están conectados a endpoints. | El stock mostrado se fija artificialmente en `20`; no se encontró modelo de existencias conectado al flujo de inventario. Aplicar autorización por restaurante. |
| Dashboard y analítica | **PARCIAL** | El dashboard calcula métricas a partir de pedidos cargados en memoria. El backend ofrece endpoints analíticos aparte. | Consumir analítica real, definir periodo/moneda/criterios, y evitar presentar cálculos locales como ventas/KPIs oficiales. |
| Predicción IA | **INCOMPLETO** | El backend contiene rutas de predicción, pero la pestaña Flutter se representa con un widget vacío. | Conectar la interfaz al modelo o retirar/etiquetar la pestaña hasta que esté disponible. La integración con Weka no se verificó en ejecución. |
| Notificaciones | **PARCIAL** | El backend tiene consulta de notificaciones, pero hay métodos sin implementar y el administrador muestra avisos de ejemplo. | Conectar notificaciones reales, estados de lectura y origen temporal; quitar avisos simulados. |
| Recompensas | **INCOMPLETO** | La pestaña contiene solo título/icono y el botón «Unirme» no ejecuta acción. | Implementar el programa o retirar temporalmente la navegación y el CTA. |
| Recuperación de contraseña | **INCOMPLETO en Flutter** | El backend expone rutas de solicitud/cambio, pero el CTA de acceso indica que no está configurado. | Integrar el flujo completo, validar caducidad/uso único del token y probar entrega de correo. |
| Acceso Google/Apple | **NO IMPLEMENTADO** | Los botones se muestran, pero únicamente presentan un aviso de acción no configurada. | Implementar proveedor OAuth y flujo backend o eliminar los botones. |
| Restaurantes, eventos, ingredientes, reseñas, reportes y chatbot | **NO VERIFICADO como flujos de producto** | Existen controladores/servicios en backend, pero no se encontró un recorrido Flutter completo que los use. | Confirmar alcance comercial; conectar y probar los módulos requeridos o documentarlos fuera del producto móvil. |

### Integración y consistencia documental

- La composición actual de Flutter crea repositorios Spring Boot para autenticación, menú, pedidos y preferencias; no instancia Supabase ni `PaymentService` (el Checkout usado es el del backend).
- El documento de diseño móvil todavía describe Supabase/offline-first, predicciones completas y sincronización; esas afirmaciones no coinciden con la composición actual. El README, en cambio, dice que Predicción IA permanece vacía.
- `DESIGN.md` define la identidad Monad, pero las pantallas combinan esa paleta con colores, tipografía y controles propios (p. ej., acceso lima/negro y páginas del cliente en tonos café). No hay una aplicación uniforme del sistema visual.
- Se detectaron paquetes y código Supabase/Stripe heredados junto a la integración Spring Boot activa. Conviene definir cuál es la fuente de verdad antes de ampliar funcionalidades.

## 4. Hallazgos priorizados

| ID | Prioridad | Área | Hallazgo y evidencia | Consecuencia |
|---|---|---|---|---|
| A-01 | **CRÍTICA** | Autorización | El endpoint público de registro toma `role` del cuerpo recibido y lo asigna directamente al usuario/token: [AuthController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AuthController.java#L74). | Un registro sin autenticar puede solicitar un rol privilegiado; compromete paneles y operaciones protegidas por rol. |
| A-02 | **CRÍTICA** | Secretos | Hay credenciales de servicios dentro de [application.properties](./backend-spring-boot/src/main/resources/application.properties#L9), incluida la configuración Stripe en [application.properties](./backend-spring-boot/src/main/resources/application.properties#L13) y correo en [application.properties](./backend-spring-boot/src/main/resources/application.properties#L25), además de un secreto de firma JWT en [JwtConstant.java](./backend-spring-boot/src/main/java/com/Restaurant/config/JwtConstant.java#L6). | Riesgo de acceso a servicios, falsificación de tokens o uso indebido de cuentas. Tratar las credenciales como expuestas y rotarlas; no se reproducen sus valores en este informe. |
| A-03 | **ALTA** | Filtración por logs | El inicio de sesión imprime usuario y contraseña; el controlador administrativo también registra el JWT: [AuthController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AuthController.java#L122), [AdminRestaurantController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AdminRestaurantController.java#L33). | Las credenciales pueden quedar en consola, archivos de logs o sistemas de observabilidad. |
| A-04 | **ALTA** | Aislamiento por restaurante | Las rutas `/api/admin/**` restringen por rol, pero consultas/cambios reciben IDs de restaurante, pedido o producto sin comprobar consistentemente que pertenezcan al usuario autenticado: [AppConfig.java](./backend-spring-boot/src/main/java/com/Restaurant/config/AppConfig.java#L26), [AdminOrderController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AdminOrderController.java#L44), [AdminMenuItemController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AdminMenuItemController.java#L53), [AdminRestaurantController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AdminRestaurantController.java#L45). | Un propietario autorizado podría consultar o modificar recursos de otro restaurante si conoce/cambia el identificador. |
| A-05 | **ALTA** | Exposición de datos | La analítica exige solo autenticación, no rol administrativo ni ámbito de restaurante; la descarga de reportes también acepta cualquier usuario autenticado: [AnalyticsController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/AnalyticsController.java#L19), [ReportController.java](./backend-spring-boot/src/main/java/com/Restaurant/controller/ReportController.java#L25). | Clientes autenticados podrían consultar analítica global o descargar reportes ajenos si conocen su nombre. |
| A-06 | **ALTA** | Arranque y resiliencia | `main()` espera a que el catálogo responda antes de `runApp()` y no captura el error de carga inicial: [main.dart](./restaurantapp/lib/main.dart#L34), [spring_boot_product_repository.dart](./restaurantapp/lib/features/customer/data/repositories/spring_boot_product_repository.dart#L57). | Si el backend no responde, la app puede no mostrar ni siquiera el acceso/reintento. Acopla el inicio de sesión a la disponibilidad del catálogo. |
| A-07 | **ALTA** | Transporte y sesión | El token se guarda en `SharedPreferences`: [session_manager.dart](./restaurantapp/lib/core/session/session_manager.dart#L5). Las URL predeterminadas usan HTTP sin TLS: [api_config.dart](./restaurantapp/lib/core/network/api_config.dart#L10). | En un despliegue mal configurado, el token puede quedar expuesto en el dispositivo o viajar sin cifrado. |
| A-08 | **ALTA** | Logs y configuración productiva | `application.properties` activa SQL y trazas de red/cliente a nivel DEBUG/TRACE y configura JPA con `ddl-auto=update`: [application.properties](./backend-spring-boot/src/main/resources/application.properties#L5), [application.properties](./backend-spring-boot/src/main/resources/application.properties#L11), [application.properties](./backend-spring-boot/src/main/resources/application.properties#L72). | Posible exposición de datos y cambios de esquema no controlados al desplegar; falta perfil productivo verificable. |
| A-09 | **MEDIA** | Recuperación de sesión | Se obtiene `currentUser` y se pasa como `initialUser`, pero ese valor no participa en el enrutamiento; la pantalla splash navega siempre al acceso: [main.dart](./restaurantapp/lib/main.dart#L29), [splash_page.dart](./restaurantapp/lib/features/splash/presentation/pages/splash_page.dart#L60). | El usuario puede volver a autenticarse aunque exista una sesión persistida; comportamiento distinto al descrito en el diseño. |
| A-10 | **MEDIA** | Biométrico | La pantalla de datos habilita biometría guardando contraseña vacía: [customer_details_page.dart](./restaurantapp/lib/features/customer/presentation/pages/customer_details_page.dart#L182). | El acceso biométrico activado desde esa pantalla no puede autenticar correctamente. |
| A-11 | **MEDIA** | Datos de pago | La UI permite almacenar texto libre de método/detalles y el backend lo persiste en el usuario: [customer_details_page.dart](./restaurantapp/lib/features/customer/presentation/pages/customer_details_page.dart#L97), [User.java](./backend-spring-boot/src/main/java/com/Restaurant/model/User.java#L47). El flujo Checkout activo no usa esas preferencias. | Se recopila información que no participa en el pago y no se define su retención/protección. Debe usarse Stripe para datos de tarjeta y limitar el dato local a referencias no sensibles. |
| A-12 | **MEDIA** | Métricas falsas | El panel asigna `stock: 20` a todos los productos y las notificaciones de administrador son textos de ejemplo: [administrator_repository_impl.dart](./restaurantapp/lib/features/administrator/data/repositories/administrator_repository_impl.dart#L138), [administrator_home_page.dart](./restaurantapp/lib/features/administrator/presentation/pages/administrator_home_page.dart#L215). | El usuario puede tomar decisiones operativas con inventario/alertas que no representan el estado real. |
| A-13 | **MEDIA** | Acciones sin flujo | Recompensas, «Ver todo», «Unirme», Google/Apple y recuperación de contraseña se muestran pero no completan ninguna acción: [customer_home_page.dart](./restaurantapp/lib/features/customer/presentation/pages/customer_home_page.dart#L1441), [customer_home_page.dart](./restaurantapp/lib/features/customer/presentation/pages/customer_home_page.dart#L1978), [login_page.dart](./restaurantapp/lib/features/auth/presentation/pages/login_page.dart#L340). La pestaña de IA es vacía: [administrator_home_page.dart](./restaurantapp/lib/features/administrator/presentation/pages/administrator_home_page.dart#L618). | El usuario interpreta que existen capacidades que no están disponibles; reduce confianza y bloquea recorridos. |
| A-14 | **MEDIA** | Calidad de pruebas | La suite Flutter falla en 5 casos: 3 esperan etiquetas de una interfaz anterior (`widget_test.dart`) y 2 pruebas biométricas no inicializan el binding antes de invocar el canal nativo (`biometric_auth_service_test.dart`). | Las pruebas no ofrecen una señal confiable de regresión; un cambio de interfaz dejó pruebas base desactualizadas. |
| A-15 | **BAJA** | Mantenibilidad | `flutter analyze` detecta un uso deprecado en el formulario de administrador: [administrator_home_page.dart](./restaurantapp/lib/features/administrator/presentation/pages/administrator_home_page.dart#L356). | Deuda pequeña de compatibilidad; no bloquea por sí sola el lanzamiento. |

## 5. Validación ejecutada

| Comando | Resultado | Interpretación |
|---|---|---|
| `flutter test` | **FALLIDO**: 33 pasaron, 5 fallaron. | Tres fallos corresponden a expectativas de texto obsoletas de la interfaz en `widget_test.dart`; dos a inicialización ausente del binding en pruebas biométricas. |
| `flutter analyze` | **1 issue informativo**, comando termina con código distinto de cero. | Uso de `DropdownButtonFormField.value` deprecado en `administrator_home_page.dart`; no se reportaron errores de compilación en esta ejecución. |
| `mvnw.cmd test` | **CORRECTO**: 9 pruebas, 0 fallos, 0 errores. | Valida pruebas backend actuales, principalmente creación/idempotencia de checkout y eventos webhook. No valida credenciales reales, MySQL productivo ni autorización multi-restaurante. |

Las pruebas de UI que sí se ejecutaron cubren ciertos tamaños compactos de pantalla, catálogo, carrito y acciones básicas administrativas. No cubren todos los endpoints, estados de error, permisos cruzados, lectores de pantalla o transacciones Stripe reales.

## 6. Preparación para producción

**Dictamen: NO APROBADA.** Antes de cualquier piloto con datos/usuarios reales:

- Corregir A-01 a A-08, incluyendo rotación de credenciales y revisión de posibles logs/backups donde hayan quedado registradas.
- Desplegar exclusivamente con TLS, secretos externos, logging seguro, perfil productivo y esquema/migraciones controladas.
- Acordar qué funcionalidades realmente forman parte del lanzamiento y ocultar lo que aún sea demostrativo.
- Validar pagos, webhooks y recuperación de pagos en un entorno Stripe de prueba conectado de extremo a extremo.
- Ejecutar pruebas de autorización con cliente, propietario de restaurante y administrador sobre recursos propios y ajenos.
- Obtener evidencia de operación con MySQL y de despliegue/recuperación; las pruebas locales actuales usan infraestructura de prueba y no equivalen a ello.

## 7. Hoja de ruta recomendada

| Fase | Prioridad | Trabajo y criterio de aceptación |
|---|---|---|
| 1. Contención de seguridad | **CRÍTICA** | Revocar/rotar las credenciales expuestas, retirar su origen del repositorio y centralizar configuración. Criterio: búsqueda de secretos no encuentra credenciales activas; los logs no contienen contraseñas ni tokens. |
| 2. Identidad y permisos | **CRÍTICA** | Forzar rol seguro en registro público; implementar autorización por recurso/restaurante para pedidos, productos, restaurantes, analítica y reportes. Criterio: pruebas negativas demuestran que un usuario no lee ni modifica recursos de otro ámbito. |
| 3. Arranque y sesión | **ALTA** | Renderizar primero la app con estado de carga/error y reintento; restaurar sesión con validación del backend; usar almacenamiento seguro y HTTPS obligatorio fuera de desarrollo. Criterio: backend no disponible no bloquea el acceso a la UI y el token no se transmite por HTTP en release. |
| 4. Completar flujos prioritarios | **ALTA** | Definir y conectar recuperación de contraseña, Checkout/retorno, historial, gestión de menú e inventario real. Retirar o implementar IA, recompensas, sociales, notificaciones y acciones simuladas. Criterio: cada acción visible termina en resultado observable o se elimina/declara no disponible. |
| 5. Datos y panel operativo | **ALTA** | Definir stock, métricas, periodos y notificaciones como datos de backend; aclarar alcance de reseñas, favoritos, promociones, eventos e ingredientes. Criterio: ningún KPI/alerta de producción usa constantes o valores locales demostrativos. |
| 6. UX y accesibilidad | **MEDIA** | Unificar sistema visual y copy; añadir estados de carga/vacío/error/reintento; evaluar teclado, contraste, lectores de pantalla y escalado de texto. Criterio: pruebas manuales por rol/dispositivo y revisión WCAG documentada. |
| 7. Pruebas y salida | **ALTA** | Actualizar pruebas Flutter a la interfaz vigente, inicializar correctamente los plugins en tests y agregar cobertura de API/roles, integración MySQL, Stripe y flujos E2E. Criterio: suites verdes y evidencia reproducible para los recorridos críticos. |

### Dependencias para la siguiente etapa

Antes de codificar, conviene confirmar el alcance del producto (una o varias sedes; qué rol puede registrarse; inventario con stock o solo disponibilidad; si IA/recompensas/reseñas estarán en el lanzamiento). El diagnóstico permite comenzar la remediación de seguridad sin esas decisiones; la implementación de funcionalidades de producto debe respetar el alcance que se acuerde.

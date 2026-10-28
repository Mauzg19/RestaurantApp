# DOCUMENTO DE DISEÑO DE LA SOLUCIÓN MÓVIL
## Plataforma Integral: Restaurant Fast & AI Predictor

**Proyecto:** RestaurantApp  
**Versión del Documento:** 1.0  
**Fecha:** Octubre 2026  
**Tecnologías:** Flutter 3.x / Dart, Spring Boot 3.x, Weka Machine Learning, MySQL  

---

## 1. RESUMEN EJECUTIVO

El presente documento detalla la arquitectura de software, especificación técnica, justificación tecnológica, diagramas de navegación/casos de uso y la estrategia de integración para la aplicación móvil del sistema **RestaurantApp**. 

La aplicación móvil permite a clientes realizar pedidos y explorar el catálogo gastronómico, y a los administradores/propietarios gestionar inventario, monitorear órdenes en tiempo real y **consumir las capacidades del modelo predictivo de Machine Learning (desarrollado con Weka)** expuesto por el backend Spring Boot para proyectar la demanda, calcular la confianza estadística y categorizar platillos óptimamente.

---

## 2. ARQUITECTURA GENERAL DE LA APLICACIÓN MÓVIL

La aplicación móvil está construida bajo los principios de **Clean Architecture** (Arquitectura Limpia) y diseño guiado por el dominio (DDD), garantizando alta cohesión, bajo acoplamiento, testabilidad y facilidad para alternar fuentes de datos.

### 2.1 Capas Arquitectónicas

```
┌─────────────────────────────────────────────────────────────┐
│                 PRESENTATION LAYER (UI)                     │
│  - Widgets, Pages (Login, AdminHome, CustomerHome,          │
│    PredictionPage, SplashPage)                              │
│  - State Management & Controllers (StatefulWidgets,         │
│    ValueNotifiers, Controllers)                             │
└──────────────────────────────┬──────────────────────────────┘
                               │ usa
┌──────────────────────────────▼──────────────────────────────┐
│                    DOMAIN LAYER (Reglas)                    │
│  - Entities: AuthUser, PredictionItem, Product, Order       │
│  - Use Cases: SignIn, RegisterUser, GetProducts,            │
│    GetAdministratorDashboard, PredictCategory               │
│  - Repository Interfaces (Contratos abstractos)             │
└──────────────────────────────▲──────────────────────────────┘
                               │ implementa
┌──────────────────────────────┴──────────────────────────────┐
│                     DATA LAYER (Datos)                      │
│  - Repositories Implementation:                             │
│    * SpringBootAuthRepository                               │
│    * SpringBootPredictionRepository                         │
│    * SupabaseProductRepository / LocalFallback              │
│  - Data Sources: Remote (HTTP Client REST), Local Cache     │
└──────────────────────────────┬──────────────────────────────┘
                               │ depende de
┌──────────────────────────────▼──────────────────────────────┐
│                  CORE & INFRASTRUCTURE                      │
│  - Network: ApiConfig, HttpClientService (JWT Interceptor)  │
│  - Session: SessionManager (SharedPreferences)              │
│  - Hardware & Sensors: DeviceFeedbackService (Háptico/InApp)│
└─────────────────────────────────────────────────────────────┘
```

#### A. Capa de Dominio (`Domain Layer`)
Es el núcleo de la aplicación, completamente independiente de librerías externas o frameworks de red:
- **Entidades (`Entities`):** Modelos de negocio inmutables (`AuthUser`, `PredictionItem`, `Product`, `Order`).
- **Casos de Uso (`Use Cases`):** Encapsulan una única acción o flujo de negocio (`SignIn`, `RegisterUser`, `GetProducts`, `GetAdministratorDashboard`).
- **Contratos de Repositorios (`Repository Interfaces`):** Definen las operaciones sin detallar la implementación (`AuthRepository`, `PredictionRepository`).

#### B. Capa de Datos (`Data Layer`)
Responsable de coordinar el acceso a fuentes remotas y almacenamiento local:
- **`SpringBootAuthRepository`:** Consume `/auth/signin` y `/auth/signup`, serializa credenciales y gestiona la sesión.
- **`SpringBootPredictionRepository`:** Consume `/api/categoria/prediccion` y `/api/categoria/predicciones` del backend Spring Boot. Cuenta con una capa de **resiliencia offline y almacenamiento en caché** (`SharedPreferences`) para salvaguardar predicciones ante caídas de red.

#### C. Capa de Presentación (`Presentation Layer`)
Compuesta por vistas, componentes reutilizables y controladores de interfaz:
- Formularios reactivos de inicio de sesión y registro.
- Paneles adaptativos para Administrador (`AdministratorHomePage`) y Cliente (`CustomerHomePage`).
- Interfaz interactiva de Inteligencia Artificial (`PredictionPage`) con sliders de precio, cantidad y flags de producto vegetariano/temporada.

#### D. Capa Central (`Core Layer`)
Servicios transversales que nutren a toda la aplicación:
- **`ApiConfig`:** Resolución dinámica de la URL del backend (Android Emulator `10.0.2.2`, Web/Desktop `localhost`, IP LAN o Cloud).
- **`HttpClientService`:** Cliente HTTP con inyección automática de cabeceras (`Authorization: Bearer <jwt>`), timeouts e intercepción de errores HTTP.
- **`SessionManager`:** Persistencia segura del token JWT y el perfil de usuario.
- **`DeviceFeedbackService`:** Manejador de feedback sensorial (vibración háptica) y notificaciones in-app.

---

## 3. JUSTIFICACIÓN DE LA TECNOLOGÍA SELECCIONADA (FLUTTER vs. ANDROID NATIVO)

| Criterio | Android Nativo (Kotlin + Jetpack Compose) | Flutter (Dart) | Decisión del Proyecto |
| :--- | :--- | :--- | :--- |
| **Multiplataforma** | Limitado exclusivamente al ecosistema Android. Requiere rehacer 100% en Swift para iOS. | **Un solo código fuente** para Android, iOS, Web y Escritorio (Windows/macOS). | **Flutter (Ganador):** Permite desplegar la app en smartphones Android del personal y tablets iOS del restaurante sin duplicar costos. |
| **Time-to-Market** | Lento debido al doble esfuerzo de desarrollo y testeo multiplataforma. | **Rápido (40% - 60% menor tiempo de desarrollo)** gracias a Hot Reload y librerías transversales. | **Flutter (Ganador):** Cumple con los sprints ágiles de entrega requeridos por el negocio. |
| **Consistencia de UI/UX** | Puede haber discrepancias visuales al portar entre diferentes SO. | **Renderizado píxel a píxel idéntico** con motor gráfico propio (Impeller / Skia). | **Flutter (Ganador):** Garantiza la misma identidad de marca premium y fluidez. |
| **Rendimiento** | Acceso nativo directo (120 FPS). | **Casi nativo (60-120 FPS compilado a código de máquina AOT)**. | **Flutter (Excelente):** El rendimiento satisface completamente las operaciones de catálogo, pedidos e IA. |
| **Mantenibilidad y TCO** | Mayor costo: dos equipos de desarrollo especializados (Android y Swift). | **Menor costo total de propiedad (TCO):** Un único equipo mantiene lógica de negocio, UI y modelos. | **Flutter (Ganador):** Reduce costos de soporte, actualización de endpoints y corrección de bugs. |

### Conclusión Técnica
La elección de **Flutter** sobre Android Nativo se fundamenta en la maximización de la eficiencia operativa y presupuestaria, permitiendo cubrir tanto Android como iOS con una única base de código robusta, unificada con la Clean Architecture y con capacidad de integración directa a servicios REST de Spring Boot.

---

## 4. DIAGRAMAS DE NAVEGACIÓN Y CASOS DE USO MÓVILES

### 4.1 Diagrama de Navegación de la Aplicación

```mermaid
flowchart TD
    Splash([Splash Screen]) --> AuthCheck{¿Hay sesión activa?}
    
    AuthCheck -- Sí (Token persistido) --> RoleRouter{Verificar Rol}
    AuthCheck -- No --> LoginView[Pantalla de Inicio de Sesión]
    
    LoginView --> RegisterView[Pantalla de Registro]
    RegisterView --> LoginView
    LoginView -- "Modo Demo" --> PredictionView[Predicción IA Weka]
    
    LoginView -- Autenticación Exitosa --> RoleRouter
    
    RoleRouter -- ROLE_ADMIN / OWNER --> AdminHome[Panel Administrador]
    RoleRouter -- ROLE_CUSTOMER --> CustomerHome[Panel Cliente]
    
    subgraph Cliente
        CustomerHome --> Catálogo[Catálogo de Platillos]
        CustomerHome --> Carrito[Carrito de Compras]
        CustomerHome --> Checkout[Pago con Tarjeta / Stripe]
        CustomerHome --> MisPedidos[Historial de Pedidos]
        CustomerHome --> PerfilCliente[Configuración de Perfil]
    end
    
    subgraph Administrador
        AdminHome --> DashTab[Tab 1: Dashboard y Métricas]
        AdminHome --> OrdersTab[Tab 2: Control de Pedidos en Vivo]
        AdminHome --> InvTab[Tab 3: Gestión de Menú e Inventario]
        AdminHome --> PredTab[Tab 4: Predicción IA Weka]
        AdminHome --> ProfileTab[Tab 5: Perfil y Cierre de Sesión]
        
        DashTab -- Acceso Rápido --> PredTab
        PredTab --> SimWeka[Simulador de Parámetros ML]
        PredTab --> HistWeka[Historial y Auditoría de Predicciones]
    end
    
    ProfileTab -- Cerrar Sesión --> LoginView
    PerfilCliente -- Cerrar Sesión --> LoginView
```

### 4.2 Diagrama de Casos de Uso Móviles

```mermaid
flowchart LR
    subgraph Actores
        Cliente((Cliente))
        Admin((Administrador / Propietario))
        SpringServer((Servidor Spring Boot))
    end

    subgraph Casos de Uso Móviles
        UC1([Iniciar Sesión / Registrarse])
        UC2([Explorar Catálogo y Filtrar Menú])
        UC3([Gestionar Carrito y Realizar Pedido])
        UC4([Monitorear y Cambiar Estados de Órdenes])
        UC5([Administrar Disponibilidad y Stock])
        UC6([Simular y Ejecutar Predicción de Categoría ML])
        UC7([Consultar y Archivar Historial de Predicciones])
        UC8([Operar en Modo Offline con Sincronización])
    end

    Cliente --> UC1
    Cliente --> UC2
    Cliente --> UC3
    Cliente --> UC8

    Admin --> UC1
    Admin --> UC4
    Admin --> UC5
    Admin --> UC6
    Admin --> UC7
    Admin --> UC8

    UC1 -.->|POST /auth/*| SpringServer
    UC4 -.->|PUT /api/admin/orders| SpringServer
    UC5 -.->|PATCH /api/admin/food| SpringServer
    UC6 -.->|POST /api/categoria/prediccion| SpringServer
    UC7 -.->|GET /api/categoria/predicciones| SpringServer
```

---

## 5. ESTRATEGIA DE CONSUMO DE SERVICIOS DEL BACKEND SPRING BOOT

### 5.1 Especificación de Contratos REST y Endpoints

| Módulo | Método | Endpoint | Cabeceras | Payload de Solicitud | Respuesta Exitosa |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Auth** | `POST` | `/auth/signin` | `Content-Type: application/json` | `{"email": "...", "password": "..."}` | `200 OK` → `{"jwt": "ey...", "message": "Login Success", "role": "ROLE_ADMIN"}` |
| **Auth** | `POST` | `/auth/signup` | `Content-Type: application/json` | `{"fullName": "...", "email": "...", "password": "...", "role": "ROLE_CUSTOMER"}` | `200 OK` → `{"jwt": "ey...", "message": "Register Success", "role": "..."}` |
| **Predicción** | `POST` | `/api/categoria/prediccion` | `Authorization: Bearer <jwt>` | `{"price": 14.5, "isVegetarian": false, "isSeasonal": true, "quantity": 2}` | `200 OK` → `{"predictedCategory": "Burrito", "confidencePct": 88.5}` |
| **Predicción** | `GET` | `/api/categoria/predicciones`| `Authorization: Bearer <jwt>` | Ninguno | `200 OK` → Lista `[{"id": 1, "predictedCategory": "Burrito", "confidencePct": 88.5, ...}]` |
| **Predicción** | `PATCH`| `/api/categoria/predicciones/{id}`| `Authorization: Bearer <jwt>` | `{"archived": true}` | `200 OK` → Objeto de predicción actualizado |
| **Predicción** | `DELETE`| `/api/categoria/predicciones/{id}`| `Authorization: Bearer <jwt>` | Ninguno | `204 No Content` |
| **Predicción** | `GET` | `/api/categoria/buscar` | `Authorization: Bearer <jwt>` | Query params: `?price=...&isVegetarian=...` | `200 OK` → Lista de coincidencias |

### 5.2 Gestión de Seguridad y Sesiones (Tokens JWT)
1. **Almacenamiento Seguro:** Tras recibir el token JWT en `/auth/signin` o `/auth/signup`, `SessionManager` persiste el token de forma privada usando almacenamiento clave-valor (`SharedPreferences`).
2. **Inyección en Cabeceras:** El servicio `HttpClientService` extrae automáticamente el token y concatena la cabecera estándar:
   ```http
   Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
   ```
   Cumpliendo exactamente con la validación de `JwtTokenValidator.java` en Spring Boot.
3. **Expiración y Renovación:** Si el backend responde con código HTTP `401 Unauthorized`, la app captura la excepción `UnauthorizedApiException`, redirige al usuario a `LoginPage` y limpia las credenciales almacenadas.

### 5.3 Resiliencia de Red y Estrategia Offline-First
En entornos reales de restaurantes (como cocinas, almacenes o zonas con baja cobertura WiFi):
- **Caché Local Inteligente:** Todas las predicciones y consultas históricas se almacenan en una base de datos/caché local (`offline_cached_predictions`).
- **Heurística de Contingencia:** En caso de corte momentáneo de red al invocar el modelo, `SpringBootPredictionRepository` ejecuta un algoritmo heurístico de respaldo garantizando que la UI no se bloquee ni arroje fallos críticos.
- **Sincronización:** Una vez restablecida la conexión, los registros pendientes se concilian con la base de datos de Spring Boot.

### 5.4 Control de Errores y Timeouts
- **Timeout estándar:** Configurado a 10 segundos para llamadas convencionales y 15 segundos para inferencias de IA.
- **Códigos HTTP soportados:**
  - `200/201`: Procesamiento y mapeo a entidades de dominio.
  - `204`: Operación exitosa sin cuerpo (ej. borrado).
  - `400`: Error de validación (mensajes descriptivos de campo faltante).
  - `401`: Token inválido o no suministrado.
  - `403`: Falta de permisos (requiere rol `ROLE_ADMIN` o `ROLE_RESTAURANT_OWNER`).
  - `500`: Excepción interna del servidor Spring Boot capturada con alerta amigable.

---

## 6. PROTOTIPO MÓVIL EN ESTADO FUNCIONAL AVANZADO

Se han implementado con éxito los siguientes componentes en el proyecto `restaurantapp`:

1. **Módulo de Autenticación y Sesión:**
   - `core/session/session_manager.dart`: Persistencia de sesión y JWT.
   - `core/network/http_client_service.dart`: Consumo HTTP REST con JWT y manejo de errores.
   - `core/network/api_config.dart`: Configuración dinámica de IP/puerto de Spring Boot (5454).
   - `features/auth/data/repositories/spring_boot_auth_repository.dart`: Conexión directa a `/auth/signin` y `/auth/signup`.

2. **Módulo de Predicción de Machine Learning (Weka):**
   - `features/prediction/domain/entities/prediction_item.dart`: Entidad con métricas de precio, vegetarianismo, temporada, cantidad, categoría inferida y porcentaje de confianza.
   - `features/prediction/domain/repositories/prediction_repository.dart`: Interfaz de dominio.
   - `features/prediction/data/repositories/spring_boot_prediction_repository.dart`: Conexión real con `/api/categoria/prediccion` y `/api/categoria/predicciones` + almacenamiento offline en caché.
   - `features/prediction/presentation/pages/prediction_page.dart`: Pantalla de simulación con controles interactivos, visualización de porcentaje de confianza con barra de progreso cromática, análisis de negocio e historial.

3. **Funcionalidad Móvil Avanzada Implementada:**
   - **Feedback Sensorial Háptico y Banners In-App:** `DeviceFeedbackService` utiliza el hardware del dispositivo para emitir vibraciones táctiles (`selectionClick`, `mediumImpact`, `heavyImpact`) al variar parámetros y confirmar predicciones o alertas de inventario.
   - **Resiliencia y Modo Offline:** Almacenamiento local persistente para operar aún sin conectividad continua.

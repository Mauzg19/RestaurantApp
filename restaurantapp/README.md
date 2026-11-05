# restaurantapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Backend Spring Boot

La aplicación utiliza Spring Boot como fuente de autenticación y de datos para
menú, pedidos y direcciones. El backend persiste esos datos en MySQL; Supabase
no es el proveedor de esos flujos. La sección administrativa **Predicción IA**
se conserva vacía hasta que se integre el nuevo modelo.

1. Inicie MySQL y verifique la conexión del backend a `restaurante_ing`.
2. Desde `backend-spring-boot`, ejecute:

   ```powershell
   .\mvnw.cmd spring-boot:run
   ```

3. Desde `restaurantapp`, ejecute `flutter run`.

La URL predeterminada es `http://localhost:5454` para web/escritorio y
`http://10.0.2.2:5454` para el emulador Android. Para un teléfono físico, use la
IP LAN del equipo donde se ejecuta Spring Boot:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.20:5454
```

El backend y MySQL deben estar accesibles desde el dispositivo. No configure
credenciales de base de datos en Flutter.

Los precios del menú están en pesos colombianos (COP) como unidades enteras.
El checkout Stripe los convierte a centavos COP al crear la sesión de pago.

## Acceso biométrico

En un dispositivo compatible, la pantalla de acceso permite vincular la cuenta
con la huella al iniciar sesión usando la opción **Vincular mi huella**. Después
de guardar correctamente las credenciales, **Acceder con huella digital**
solicita la autenticación biométrica nativa y vuelve a validar la cuenta con el
backend. El acceso normal con correo y contraseña sigue disponible. La
contraseña vinculada se guarda en el almacenamiento seguro del sistema y no en
las preferencias de texto plano.

Para demostrarlo en Android:

1. Configura un bloqueo de pantalla y registra una huella en un dispositivo
   físico; o crea un emulador con sensor biométrico y registra una huella en
   **Device Manager > Edit > Show Advanced Settings > Fingerprint**.
2. Ejecuta la aplicación, inicia sesión con **Vincular mi huella** activado y
   confirma que se abre la pantalla de inicio correspondiente al usuario.
3. Cierra sesión, vuelve a la pantalla de acceso y pulsa **Acceder con huella
   digital**. El diálogo del sistema permite demostrar el sensor; al verificar
   la huella, la aplicación inicia sesión de nuevo contra el backend.

En el emulador Android se puede simular el toque registrado con
`adb -e emu finger touch 1`. En iOS, el diálogo nativo utiliza Touch ID o Face
ID, según el dispositivo. Si el dispositivo no tiene biometría configurada, el
inicio de sesión normal continúa disponible y el acceso biométrico no se activa.

## Notificaciones locales y push

Las notificaciones de pedidos se guardan en Spring Boot y aparecen en la bandeja
del usuario autenticado: el propietario del restaurante recibe pedidos pagados
y el cliente recibe los cambios de estado. La bandeja se sincroniza al iniciar
sesión, al abrirla y periódicamente mientras la sesión está activa. En primer
plano, los avisos nuevos también se muestran como notificación local del
dispositivo; en segundo plano o con la app cerrada, Firebase Cloud Messaging
(FCM) entrega la notificación push.

Para activar push, registre las aplicaciones Android e iOS en el mismo proyecto
Firebase y configure una clave APNs en Firebase para iOS. Los identificadores
Android/iOS actuales del proyecto son `com.example.restaurantapp`; los
identificadores configurados en Firebase deben coincidir, o deben actualizarse
los IDs de aplicación del proyecto antes de compilar. Inicie la app pasando los
identificadores del proyecto y de ambas aplicaciones:

```powershell
flutter run `
  --dart-define=FIREBASE_API_KEY="your-api-key" `
  --dart-define=FIREBASE_PROJECT_ID="your-project-id" `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="your-sender-id" `
  --dart-define=FIREBASE_ANDROID_APP_ID="your-android-app-id" `
  --dart-define=FIREBASE_IOS_APP_ID="your-ios-app-id" `
  --dart-define=FIREBASE_IOS_BUNDLE_ID="your.ios.bundle.id"
```

En Android se solicita el permiso de notificaciones después del inicio de
sesión. En iOS el proyecto incluye el entitlement de APNs para desarrollo; para
probar y publicar, habilite Push Notifications para el App ID, configure la
capacidad y perfil de firma en Apple Developer y asocie la clave APNs en
Firebase. Sin identificadores Firebase, la bandeja del backend sigue disponible
y sincroniza los avisos, pero no se registran tokens ni se envían notificaciones
push.

El backend requiere además `GOOGLE_APPLICATION_CREDENTIALS` apuntando a una
cuenta de servicio de Firebase del mismo proyecto. Mantenga ese archivo fuera
del repositorio y no use una cuenta de servicio en la aplicación Flutter.
Valide la entrega en dispositivos físicos con la app abierta, en segundo plano
y cerrada; las pruebas automatizadas no sustituyen esa verificación con FCM/APNs.

## Uso offline

En Android/iOS, el menú y las categorías, los pedidos y la dirección de entrega
se guardan en SQLite y se particionan por correo de usuario. El carrito sigue
persistiéndose por cuenta. Las operaciones de menú, dirección y estado de pedido
que no pueden enviarse por falta de red se conservan en una cola local; la
aplicación detecta el regreso del backend y las reintenta con espera incremental.
La creación de productos, direcciones y pedidos lleva claves idempotentes para
que los reintentos no creen duplicados. El estado de red se comprueba contra el
endpoint del backend, no solo contra la conexión Wi-Fi o móvil.
La interfaz no reserva una franja fija para mostrar el estado de conexión:
informa con avisos breves solo cuando se pierde la red, hay sincronización
pendiente o se produce un error.

Un pedido creado sin conexión queda como borrador pendiente: no se confirma ni
se cobra offline. Al recuperar el backend, se crea la sesión Checkout de Stripe
y el usuario debe abrirla para completar el pago. No se guardan datos de tarjeta.
El inicio de sesión nuevo, el registro, el pago/Checkout, las recompensas, las
notificaciones remotas y la carga de imágenes requieren conexión. Una sesión
previamente iniciada se restaura solo mientras su JWT guardado en el almacén
seguro del sistema siga vigente; la app no guarda contraseñas para autenticar
offline.

Para probar en un teléfono Android físico:

1. Conecte el teléfono y el equipo que ejecuta Spring Boot a la misma red.
   Inicie MySQL y el backend; permita el puerto `5454` en el firewall del equipo.
2. Desde `restaurantapp`, inicie la app indicando la IP LAN del equipo:

   ```powershell
   flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.20:5454
   ```

   Sustituya `192.168.1.20` por la IP real. Esta configuración HTTP está
   habilitada para ejecución debug; para publicar, configure HTTPS en el
   backend y use una URL HTTPS.
3. Inicie sesión y consulte el menú; cree o actualice un borrador de pedido y
   una dirección. Active modo avión, cierre la app completamente y ábrala de
   nuevo. La sesión debe seguir vigente y el contenido cacheado debe aparecer.
4. Desactive modo avión y espere el indicador de sincronización. Confirme que el
   borrador aparece en pedidos, abra Checkout y complete el pago por separado.

Ejecute las pruebas locales de persistencia, aislamiento, reintentos y pedidos:

```powershell
cd .\restaurantapp
flutter test test\core\offline test\features\customer\data\repositories\spring_boot_order_offline_test.dart
flutter test test\features\customer\data\repositories\spring_boot_product_offline_test.dart test\features\customer\data\repositories\spring_boot_user_settings_offline_test.dart
flutter analyze
```

La persistencia SQLite de esta implementación está disponible en plataformas
nativas; la versión web no habilita esta base local. La sincronización se
ejecuta mientras la app está activa; Android puede suspenderla en segundo plano,
por lo que las operaciones se reintentan al reabrir la app o cuando vuelve a
detectarse el backend. La prueba final en un teléfono real requiere el servidor,
MySQL, la red local y las credenciales del entorno de desarrollo.

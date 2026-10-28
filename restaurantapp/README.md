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

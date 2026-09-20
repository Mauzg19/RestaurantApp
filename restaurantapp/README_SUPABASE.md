# Supabase

Proyecto: `restaurant`
Project ID: `owshtbrfipmldwgjepyr`

## Configuración

1. Abre el SQL Editor de Supabase.
2. Ejecuta `supabase/schema.sql`.
3. Obtén la `Publishable key` desde Project Settings > API.
4. Ejecuta la app con:

```powershell
flutter run --dart-define=SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY
```

Las cuentas nuevas se crean como clientes. Para dar permisos de administrador,
ejecuta en el SQL Editor:

```sql
update public.profiles set role = 'administrator'
where id = (select id from auth.users where email = 'admin@restaurant.com');
```

Después de aplicar el esquema, comprueba que el permiso quedó activo:

```sql
select u.email, p.role
from auth.users u
join public.profiles p on p.id = u.id
where u.email = 'admin@restaurant.com';

select polname, polcmd
from pg_policies
where schemaname = 'public' and tablename = 'orders';
```

El primer resultado debe mostrar `administrator` y el segundo debe incluir
`administrators can update orders` con `polcmd = 'u'`. Si no aparece, vuelve a
ejecutar todo `supabase/schema.sql` en el SQL Editor.

El formulario público de registro no permite seleccionar el rol administrador.
Para crear el único administrador, registra primero su correo desde **Authentication
> Users > Add user**, establece su contraseña y luego ejecuta la actualización de
`profiles` anterior.

La URL se construye automáticamente como `https://owshtbrfipmldwgjepyr.supabase.co`.

Sin `SUPABASE_ANON_KEY`, la app usa los repositorios locales para desarrollo y pruebas. Nunca pongas una `Secret key` o `service_role` key dentro de Flutter.

La Secret key compartida durante la configuración debe revocarse y regenerarse desde
Project Settings > API. No es necesaria para esta aplicación móvil o de escritorio.

## Error `email rate limit exceeded`

Este error pertenece al correo de autenticación de Supabase. Para desarrollo:

1. Abre **Authentication > Providers > Email**.
2. Desactiva temporalmente **Confirm email**.
3. Guarda los cambios.
4. Espera unos minutos antes de volver a intentar con el mismo correo.

Con **Confirm email** desactivado, el registro no depende del correo de prueba y
el usuario debe aparecer en **Authentication > Users** y en `public.profiles`.
En producción debes usar un proveedor SMTP propio y volver a activar la confirmación.

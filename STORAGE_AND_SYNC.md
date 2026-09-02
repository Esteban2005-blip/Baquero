# Almacenamiento y sincronización

## Clasificación y mecanismo

| Dato | Clasificación | Mecanismo | Retención y finalidad |
|---|---|---|---|
| `access_token`, `refresh_token`, usuario y rol de sesión | Secreto/autenticación | `flutter_secure_storage` (Keychain/Keystore) | Hasta cerrar sesión; mantener la sesión entre cierres de la app. |
| Notas descargadas | Personal/contenido | SQLite local (`notes`) | Mientras exista la sesión; lectura sin conexión y edición local. |
| Operaciones pendientes | Personal/operacional | SQLite local (`pending_operations`) | Hasta sincronizar o cerrar sesión; reintentar escrituras offline. |
| Fecha de caché | Metadato operacional | SQLite (`cached_at`) | Junto a la caché; informar su antigüedad. |
| Configuración de API | Configuración no secreta | `.env`/variables de compilación | Durante la instalación; seleccionar endpoint y timeout. No contiene tokens. |
| Formularios y mensajes | Efímero | Memoria de widgets | Solo durante la pantalla; no se persiste. |

## Base de datos local

Se mantiene SQLite porque la aplicación ya usa `sqflite`, necesita consultas ordenadas y transacciones, y el formato es portable entre Android, iOS y escritorio. Desde el punto de vista de mantenimiento, se evita introducir un segundo motor: el esquema versionado queda en una única clase (`DBHelper`) y las operaciones de cola se prueban con la misma transacción que la caché.

Esquema principal:

- `notes(id, client_id UNIQUE, user_id, title, content, createdAt, cached_at)`.
- `pending_operations(operation_id PRIMARY KEY, user_id, type, payload, created_at)`.

`client_id` identifica una nota creada offline y `operation_id` identifica cada operación de forma única. No se guarda ninguna contraseña local.

## Offline, reintentos y conflictos

La pantalla de notas muestra SQLite aunque no haya conexión y presenta `Actualizado hace ...`. Altas, cambios y borrados se escriben primero en la caché y en `pending_operations`. Al recuperar conectividad se procesa la cola en orden de creación; cada operación admite tres intentos con espera creciente de 1, 2 y 4 segundos. Los errores HTTP 4xx no se reintentan.

La estrategia de conflictos es **última escritura sincronizada gana**: la cola se procesa en orden y la respuesta del servidor confirma el estado remoto. Es simple y determinista, pero sacrifica la detección de ediciones concurrentes y puede sobrescribir cambios realizados desde otro dispositivo. El cierre de sesión elimina toda la base local y el registro cifrado de sesión, incluso si quedan operaciones pendientes.
# Almacenamiento y sincronización

La implementación actual usa `note_cache`, `cache_metadata` y `outbox` en SQLite
v4. Credenciales: `flutter_secure_storage`; nunca contraseñas en SQLite.

Cada caché y operación tiene un `owner_id` independiente del autor remoto. Los
UUID locales y los ID del servidor son distintos. La escritura optimista y la
operación pendiente son atómicas. El servidor confirma cada creación mediante un
recibo de idempotencia persistido; las respuestas perdidas no duplican registros.

Los pendientes rechazados se conservan para corrección. Las operaciones de v3 se
migran marcadas para revisión, ya que la versión anterior no guardaba claves de
idempotencia. El cierre de sesión elimina la caché y cola de la cuenta que sale.

Consulta [SEMANA_13.md](SEMANA_13.md) para el contrato completo y
[las pruebas](test/repository_test.dart) para los casos de recuperación.

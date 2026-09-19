# Semana 13 - Integración de Baquero Notes

Repositorio de entrega: https://github.com/Reos98/Baquero

Base del trabajo: https://github.com/Esteban2005-blip/Baquero, commit `29386de`.
Se conserva el historial del proyecto y del repositorio de destino. La aplicación
Flutter de `lib/` consume la API Flask de `backend/`. Las carpetas duplicadas de
versiones anteriores se retiran del árbol de entrega; siguen en el historial Git.

## Configuración y justificación del cliente

`main.dart` construye un solo `ApiService`, compartido por las pantallas. Este
servicio posee una única instancia de Dio y funciona como fuente remota. Se eligió
Dio por sus interceptores asíncronos, adaptadores sustituibles en pruebas y tiempos
de espera separados. Conexión: 10 s; envío: 15 s; recepción: 20 s.

`API_BASE_URL` y `APP_ENV` son valores públicos de configuración suministrados con
`--dart-define`. No contienen claves. El cliente no carga archivos `.env` como
assets. En Android emulado se usa `http://10.0.2.2:5000/api`. En un celular conectado
por USB se ejecuta `adb reverse tcp:5000 tcp:5000` y se usa
`http://127.0.0.1:5000/api`. En producción, y en toda compilación release, se exige
una dirección HTTPS y se impiden redirecciones automáticas.

## Interceptores y orden

1. **AuthenticationInterceptor:** lee la sesión de `flutter_secure_storage` en cada
   solicitud protegida e inyecta `Authorization: Bearer ...`. Las pantallas no
   transportan tokens a los métodos CRUD. Un reintento no puede cambiar de cuenta.
2. **RefreshInterceptor:** ante un 401 protegido llama a `/auth/refresh` usando el
   refresh token. Las solicitudes concurrentes comparten una sola renovación.
   Guarda la nueva sesión antes de reenviar; marca `authRetried=true` para permitir
   solo una renovación por solicitud. El refresh no se renueva a sí mismo. Un
   refresh rechazado borra las credenciales; un fallo de conexión las conserva.
   El backend devuelve solo un access token nuevo: el cliente conserva el refresh
   original. Cerrar sesión durante la renovación no resucita la sesión anterior.
3. **SafeRetryInterceptor:** máximo dos reintentos con esperas de 400 y 800 ms para
   fallos transitorios. Solo GET, HEAD, PUT, DELETE, OPTIONS y POST con una clave de
   idempotencia persistida. Login y registro no se repiten automáticamente.
4. **SafeLogInterceptor:** únicamente en desarrollo; registra método, ruta sin
   consulta y estado. Nunca registra cabeceras, cuerpos, notas ni credenciales.

La renovación ante 401 es una recuperación de autenticación, separada del
reintento por transporte. El backend verifica el JWT antes de ejecutar la mutación.

## Correspondencia entre servidor y cliente

Los modelos `Note` y `Session` usan `json_serializable` y `json_annotation`. Los
archivos `note.g.dart` y `session.g.dart` se generan con `dart run build_runner build`
y se incluyen en el repositorio. `checked: true` detecta respuestas incompatibles;
no convierte silenciosamente una respuesta inválida en una lista vacía.

| Entidad | Campo JSON | Campo Dart | Tipo y regla |
| --- | --- | --- | --- |
| Note | id | id | int nullable; nulo hasta recibir ID remoto |
| Note | client_id | clientId | String nullable en red; identidad local estable |
| Note | user_id | userId | int nullable; autor real del registro |
| Note | author_email | authorEmail | String nullable; dato adicional de lectura |
| Note | title | title | String obligatorio; 3 a 100 caracteres |
| Note | content | content | String obligatorio; 1 a 5000 caracteres |
| Note | createdAt | createdAt | int obligatorio; Unix en milisegundos |
| Session | user_id | userId | int obligatorio |
| Session | email | email | String obligatorio |
| Session | role | role | String; valor predeterminado user |
| Session | access_token | accessToken | String obligatorio; solo almacén seguro |
| Session | refresh_token | refreshToken | String obligatorio; se conserva al renovar |

Las respuestas exitosas envuelven el resultado en `data`; los listados incluyen
`pagination`. El cliente consume todas las páginas. Los errores incluyen
`error.code`, `error.message` y, cuando corresponde, `error.fields` con listas de
mensajes por campo. Login/registro devuelven además `token_type` y `expires_in`;
estos campos informativos no forman parte de la sesión persistida.

## Capa de datos y trabajo sin conexión

Las pantallas llaman a `NotesRepository`; el repositorio coordina `ApiService`
(fuente remota) y `DBHelper` (fuente local SQLite). Una cola de futuros serializa
carga, edición, borrado, sincronización y cierre de sesión para evitar carreras.

SQLite v4 separa `owner_id` (cuenta que mantiene la caché), `client_id` (UUID local)
y `Note.id` (ID asignado por el servidor). Así se evita el error previo por el que
SQLite asignaba a las notas sin conexión un número que se confundía con un ID
remoto. `note_cache`, `cache_metadata` y `outbox` guardan datos, antigüedad y cola.
Cada escritura optimista y su operación pendiente se guardan en una transacción.

Cada creación tiene una `Idempotency-Key` y un cuerpo inmutable persistidos antes
de enviarse. El backend guarda en una sola transacción la nota y el recibo de
idempotencia. Si se pierde la respuesta después del commit, el mismo envío devuelve
el mismo resultado sin insertar otra nota. Reutilizar una clave con otro cuerpo
devuelve 409. Al recibir el ID remoto se actualizan las operaciones posteriores
para que editar o borrar una nota creada sin conexión siga funcionando.

La caché muestra antigüedad, estado sin conexión y número de pendientes. Una
instantánea del servidor se combina con las operaciones locales; no reaparecen
notas con borrado pendiente. Los rechazos permanentes se conservan con su mensaje
y requieren corrección, en lugar de reenviarse indefinidamente. Los errores 422 se
muestran bajo su campo. Los fallos de autenticación no se ocultan como datos vacíos.

La migración desde v3 conserva las notas y marca las operaciones antiguas para
revisión: al no existir recibos de idempotencia en esa versión, reenviarlas sin
revisión podría duplicar datos. Cerrar sesión elimina la caché y cola de esa cuenta.
Las notas locales no están cifradas; las credenciales sí. No se guardan contraseñas
en SQLite. Este alcance distingue el cifrado de credenciales del de contenido.

## Cuatro familias de error

| Familia | Ejemplos | Comportamiento |
| --- | --- | --- |
| Conectividad | Sin red, conexión rechazada, DNS | Mensaje sin conexión; caché y cola disponibles |
| Tiempo de espera | Conexión, envío o recepción excedidos | Mensaje de espera agotada; reintento seguro limitado |
| Cliente 4xx | 401, 403, 409, 422 | Renovación si procede; autorización o errores por campo; sin reintentos de transporte |
| Servidor y contrato | 5xx, JSON incompatible | Mensaje de servidor; 5xx admite reintento seguro, contrato inválido no |

Los certificados inválidos no se aceptan ni se reintentan. Una cancelación tampoco
activa reintentos. Los mensajes específicos del servidor se conservan cuando están
disponibles; un error desconocido no expone trazas técnicas al usuario.

## Verificación de seguridad

- Se retiran del seguimiento `.env`, la base de datos de ejemplo, archivos de IDE
  y el archivo temporal de Word. El historial Git anterior no se reescribe.
- El secreto JWT se genera aleatoriamente en desarrollo si no se configura. En
  producción se exige `JWT_SECRET_KEY` externa de al menos 32 caracteres. Los
  `dart-define` son públicos y no son mecanismos de secreto.
- Android release deshabilita tráfico HTTP y copias de seguridad de la aplicación.
  Solo el manifiesto debug permite HTTP para pruebas locales.
- El servidor exige HTTPS en producción, desactiva debug, limita el cuerpo de las
  solicitudes y responde con `Cache-Control: no-store` y `nosniff`.
- CORS tiene una lista de orígenes explícita. Un `X-Forwarded-Proto` arbitrario no
  permite saltarse la exigencia HTTPS; el proxy de producción debe configurarse
  explícitamente como confiable.
- Las consultas SQLite usan parámetros. La propiedad de notas y los roles se
  comprueban en el servidor. Cambiar un rol tiene efecto inmediato.
- Cerrar sesión revoca access y refresh mediante una sesión persistente en SQLite;
  la revocación sigue vigente después de reiniciar el backend.
- Release no usa la clave debug: permanece sin firmar hasta configurar una clave
  propia mediante `android/key.properties`, excluido de Git junto con los keystores.

## Reproducción

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements.txt
# Para demostrar expiración: $env:ACCESS_TOKEN_SECONDS = '60'
python -m backend.app
```

En otra terminal:

```powershell
flutter pub get
dart run build_runner build
adb reverse tcp:5000 tcp:5000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
```

Para emulador, usar `http://10.0.2.2:5000/api`. Para producción, usar HTTPS, un
servidor WSGI apropiado y secretos suministrados por el entorno de despliegue. El
servidor Flask integrado se usa solo para desarrollo.

`tools/verify.ps1` ejecuta generación, análisis y pruebas. `backend/tests/test_api.py`
verifica el backend contra bases temporales. `test/api_service_test.dart` prueba
interceptores con transporte controlado, `test/repository_test.dart` usa SQLite real
en memoria y `test/widget_test.dart` comprueba pantallas. La evidencia de ejecución
y el recorrido en el teléfono se documentan en `evidence/semana13/RESULTADOS.md`.

## Referencias técnicas

- Dio: https://pub.dev/packages/dio
- Serialización Flutter: https://docs.flutter.dev/data-and-backend/serialization/json
- Revocación JWT: https://flask-jwt-extended.readthedocs.io/en/stable/blocklist_and_token_revoking.html

# Baquero Notes - Semana 13

Aplicación Flutter integrada con su backend Flask: autenticación JWT, renovación
automática, notas con SQLite local, cola de salida e idempotencia en el servidor.

**Entrega:** [documentación técnica](SEMANA_13.md) ·
[informe Word](evidence/semana13/Informe_Semana_13_Baquero.docx) ·
[guion Word](evidence/semana13/Guion_Video_Semana_13_Baquero.docx) ·
[video en Android](evidence/semana13/Video_Semana_13_Baquero.mp4) ·
[resultados y evidencia](evidence/semana13/RESULTADOS.md) ·
[repositorio](https://github.com/Reos98/Baquero).

## Ejecutar el backend

Requiere Python 3.12 o posterior. Desde la raíz del repositorio:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements.txt
python -m backend.app
```

La API escucha en `http://127.0.0.1:5000/api`. Se crea una base SQLite local al
iniciar. Registra una cuenta desde la aplicación; no se distribuyen usuarios ni
contraseñas de acceso. Puedes copiar `backend/.env.example` a `backend/.env` para
configurar el entorno. Sin secreto configurado, desarrollo genera uno aleatorio y
requiere iniciar sesión otra vez después de reiniciar el servidor.

## Ejecutar la aplicación Android

Validada con Flutter 3.47.4 / Dart 3.13.3, Java 17 y Android SDK 36. Instala las
dependencias y genera los modelos:

```powershell
flutter pub get
dart run build_runner build
```

Emulador Android:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

Celular conectado por USB con depuración autorizada:

```powershell
adb devices
adb reverse tcp:5000 tcp:5000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000/api
```

La variante debug usa `com.example.aplicacion_moviles.semana13` para coexistir con
instalaciones anteriores. El backend debe permanecer activo durante las pruebas
en línea. Para demostrar renovación, inicia el servidor con
`ACCESS_TOKEN_SECONDS=60` antes de iniciar sesión.

Para grabar el recorrido con trazas que solo contienen método, ruta y estado HTTP:

```powershell
python tools/demo_server.py --database backend/demo.sqlite --events demo-events.jsonl
```

Este servidor de demostración usa tokens de 60 segundos y una base separada. El
registro excluye cabeceras, cuerpos y credenciales. Se usa solo en desarrollo.

## Comprobaciones

```powershell
flutter analyze
flutter test
python -m pytest -q
```

También puedes ejecutar `tools/verify.ps1` desde una terminal que tenga Flutter y
Python. Las pruebas usan una base temporal independiente de la base de la app.

## Estructura

- `lib/api_service.dart`: fuente remota, cliente Dio e interceptores.
- `lib/session_storage.dart`: almacenamiento cifrado de credenciales.
- `lib/note.dart`, `lib/session.dart`: modelos y serialización generada `.g.dart`.
- `lib/db_helper.dart`: caché SQLite v4, metadatos y cola de operaciones.
- `lib/notes_repository.dart`: sincronización y manejo de datos sin conexión.
- `lib/screens/`: pantallas de acceso, registro y notas.
- `backend/app.py`: API, autorización, validación 422 y recibos de idempotencia.
- `backend/tests/`, `test/`: pruebas de contrato, cliente, SQLite y pantallas.
- `evidence/semana13/`: evidencia correspondiente a esta entrega.

Las cuatro familias de fallos, orden de interceptores, correspondencia de campos,
seguridad y limitaciones se explican en [SEMANA_13.md](SEMANA_13.md).

## Producción

Define `APP_ENV=production` y un `JWT_SECRET_KEY` externo de al menos 32 caracteres
en el backend. Ejecuta la API con un servidor WSGI y TLS. No confíes en cabeceras de
proxy sin configurar explícitamente el proxy de despliegue.

```powershell
flutter build apk --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://tu-servidor/api
```

Toda compilación release exige HTTPS y desactiva registros HTTP. Configura tu
propia firma Android en `android/key.properties` (storeFile, storePassword,
keyAlias y keyPassword) antes de distribuir una versión pública. Ese archivo y
los keystores se excluyen de Git; release permanece sin firmar si no se configuran.

## Procedencia

Trabajo basado en [Esteban2005-blip/Baquero](https://github.com/Esteban2005-blip/Baquero),
commit `29386de`. Se conserva el historial completo. Las carpetas duplicadas con
fechas, datos de ejecución, configuración de IDE y archivos temporales se retiran
del árbol actual para que exista una sola implementación activa. Los informes y
capturas antiguos corresponden a entregas previas; no acreditan la Semana 13.

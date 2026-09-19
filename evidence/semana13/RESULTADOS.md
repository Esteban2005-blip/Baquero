# Resultados de Semana 13

## Comprobaciones automatizadas

- `flutter analyze`: sin incidencias.
- `flutter test`: 28 pruebas aprobadas.
- `python -m pytest -q`: 21 pruebas aprobadas.
- Generación real de `note.g.dart` y `session.g.dart` con build_runner.
- Entorno: Flutter 3.47.4, Dart 3.13.3, Python 3.12.14, Java 17, Android SDK 36.

## Cobertura

Backend: registro y acceso reales, CRUD, expiración y renovación, revocación
persistente tras reiniciar, 422 por campo, entradas de tipo incorrecto, aislamiento
entre cuentas, roles actualizados, idempotencia concurrente, recuperación después
de borrar un registro, paginación, HTTPS y exportación JSON real.

Cliente: lectura de credenciales en cada envío, una renovación para varios 401,
protección frente a 401 persistente, refresh inválido, conservación de credenciales
ante pérdida de red, 422 visible por campo, reintentos idempotentes con cuerpo
estable, ausencia de reintentos en login, paginación, contrato inválido, HTTPS y
registros sin credenciales.

Se verifica además que cerrar sesión durante una renovación no restaure las
credenciales, que cambiar de cuenta impida reenviar una petición de la sesión
anterior, que JSON malformado no se reintente y que los modelos generados
conserven campos opcionales nulos.

SQLite y repositorio: creación sin conexión con ID remoto nulo, respuesta perdida
seguida de edición, borrado de una creación aún no confirmada, corrección de un
borrador rechazado, antigüedad de listas vacías, aislamiento de caché, acciones
concurrentes y superposición de borrados pendientes.

## Dispositivo físico

Pruebas realizadas el 11 de septiembre de 2026 (America/Guayaquil), en un BRP_NX3
con Android 16 / API 36, conectado por USB. El APK debug ARM64 compiló correctamente
y `adb install` devolvió `Success`. Aplicación: `com.example.aplicacion_moviles.semana13`.

| Recorrido observado | Resultado |
| --- | --- |
| Inicio de sesión y listado | `POST /api/auth/login 200`, seguido de `GET /api/notes 200`; se muestra una nota real previamente guardada en Flask/SQLite. |
| Creación desde Android | `POST /api/notes 201`; la nueva nota aparece en el listado. |
| Token vencido | Con vigencia de 60 segundos, a los 79 segundos la consulta devuelve `401 TOKEN_EXPIRED`, luego `POST /api/auth/refresh 200` y la consulta repetida `200`, sin volver a pedir credenciales. |
| Validación por campo | Registro con `demo@invalido`: HTTP `422 VALIDATION_ERROR`, `error.fields.email` y mensaje visible bajo el correo. |
| Sin conexión con el backend | Se retira únicamente `adb reverse tcp:5000`: las notas siguen visibles y aparece el aviso de falta de conexión. |
| Escritura sin conexión | La nota se guarda localmente y el contador muestra un cambio pendiente. |
| Recuperación | Se restaura el túnel y se pulsa actualizar: creación `201`, listado `200` y cero cambios pendientes. Una nueva actualización no duplica la nota. |
| Persistencia | Se detiene y vuelve a abrir el proceso de la app sin enlace al servidor: conserva la sesión cifrada, la caché y el aviso sin conexión. |

Consulta directa a la base de demostración después de sincronizar: tres notas,
una fila para cada título (`Integracion con el backend`, `Nota creada desde Android`
y `Nota sin conexion`). Las notas de demostración y sus credenciales no se incluyen
en la base distribuida.

El primer intento de compilación encontró permisos de Java en el entorno
restringido; se completó desde la sesión de Windows del propietario. También se
corrigió el conflicto de manifiestos entre HTTP local de debug y HTTPS obligatorio
de release, mediante una sustitución explícita limitada al manifiesto debug.

## Archivos de entrega

- [Video explicativo del recorrido](Video_Semana_13_Baquero.mp4): grabación real
  del teléfono con explicaciones en pantalla y narración sintética en español
  de Ecuador, voz Luis. Duración aproximada: 3 minutos y 12 segundos. Se omiten
  pausas entre capítulos y se acelera la escritura; no se simulan respuestas.
  El último fotograma de algunas escenas se prolonga para terminar la explicación.
  No contiene el texto pequeño de la esquina inferior izquierda.
- [Informe breve en Word](Informe_Semana_13_Baquero.docx): configuración, interceptores,
  correspondencia de modelos, errores y verificación de seguridad.
- [Guion en Word](Guion_Video_Semana_13_Baquero.docx): texto de la narración,
  tiempos por escena y recomendaciones para grabarlo con voz propia.
- [Narración y tiempos](narracion.json): texto exacto y tiempos del video hablado.
  `edicion-video.json` describe las capturas base antes de añadir la voz.
- [Eventos HTTP](eventos-http.jsonl): fechas UTC, método, ruta, estado y nombres
  de campos inválidos. Sin cabeceras, cuerpos, tokens ni contraseñas.
- Capturas `01-acceso.png` a `10-cache-tras-reinicio.png`: pantallas observadas.

## Límites de la validación

La demostración usa el backend local del proyecto y una cuenta creada para las
pruebas. No acredita un despliegue público ni una compilación release firmada.
La desconexión se provocó retirando el enlace al backend, sin alterar la conexión
personal a Internet del teléfono. La cobertura automática incluye fallos de
transporte y concurrencia que no se fuerzan en cada escena del video.

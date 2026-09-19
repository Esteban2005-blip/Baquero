# Informe breve: capacidades del dispositivo en Baquero Notes

## 1. Identificacion del proyecto

- **Proyecto:** Baquero Notes.
- **Repositorio principal:** https://github.com/Esteban2005-blip/Baquero
- **Repositorio de referencia configurado:** https://github.com/Reos98/Baquero
- **Version:** 1.0.0+1.
- **Plataforma demostrada:** Android en dispositivo fisico.
- **Backend local de demostracion:** `http://192.168.68.114:5000/api`.

> Para la demostracion local, el telefono y el equipo que ejecuta Flask deben permanecer en la misma red Wi-Fi. Para un despliegue publico se debe sustituir la URL HTTP local por un dominio HTTPS.

## 2. Justificacion de las capacidades elegidas

### Camara

Las notas pueden enriquecerse con evidencia visual tomada directamente desde el telefono. La camara es pertinente porque permite asociar una fotografia al contexto de una nota, por ejemplo, una evidencia de trabajo, un objeto o una situacion que el usuario quiera recordar.

### Ubicacion

La ubicacion permite contextualizar una nota con el lugar donde fue creada o revisada. Es pertinente para recordatorios de campo, visitas, actividades academicas y registros asociados a un sitio.

Ambas capacidades son opcionales. Una nota de texto debe seguir funcionando si el usuario no concede ninguno de los permisos.

## 3. Plugins verificados

| Plugin | Version declarada | Uso en el proyecto | Verificacion |
|---|---:|---|---|
| `permission_handler` | `^12.0.1` | Solicitar permisos y abrir los ajustes del sistema cuando existe denegacion permanente. | Declarado en `pubspec.yaml`, importado en `device_capabilities.dart` y utilizado desde el editor. |
| `image_picker` | `^1.0.8` | Abrir la camara y obtener una imagen seleccionada. | Declarado en `pubspec.yaml` y utilizado por `DeviceCapabilitiesService`. |
| `geolocator` | `^14.0.2` | Verificar el servicio de ubicacion y obtener coordenadas actuales. | Declarado en `pubspec.yaml` y utilizado por `DeviceCapabilitiesService`. |

La resolucion efectiva de dependencias se comprobo con `flutter pub get`. El analisis estatico finalizo con `No issues found!` y las pruebas existentes terminaron con `All tests passed!`.

## 4. Permisos declarados

| Permiso Android | Proposito | Momento de uso | Degradacion |
|---|---|---|---|
| `android.permission.INTERNET` | Comunicacion con el backend de autenticacion y notas. | Al iniciar sesion y sincronizar. | La app conserva los datos localmente y deja operaciones pendientes. |
| `android.permission.CAMERA` | Capturar una fotografia desde el editor de notas. | Cuando el usuario pulsa `Foto`. | La nota se guarda sin fotografia y se informa el motivo. |
| `android.permission.READ_MEDIA_IMAGES` | Acceso a imagenes en Android moderno para seleccionar una imagen de galeria. | Cuando se usa la seleccion desde galeria. | La nota continua siendo de texto si el acceso se deniega. |
| `android.permission.ACCESS_FINE_LOCATION` | Obtener ubicacion precisa para una nota. | Cuando el usuario pulsa `Ubicacion` y el servicio esta activo. | Se guarda la nota sin coordenadas. |
| `android.permission.ACCESS_COARSE_LOCATION` | Permitir ubicacion aproximada cuando el sistema o el usuario no conceden precision fina. | Durante la solicitud de ubicacion. | Se conserva la nota sin ubicacion si no hay permiso. |

El manifiesto tambien contiene `android:usesCleartextTraffic="true"` para la demostracion local con Flask sobre HTTP. Esta configuracion no debe mantenerse en un despliegue publico: la API debe usar HTTPS.

## 5. Flujo de permisos

1. El usuario abre el editor de notas.
2. El usuario pulsa `Foto` o `Ubicacion`.
3. `DeviceCapabilitiesService` solicita el permiso correspondiente.
4. Si el permiso se concede, se ejecuta la capacidad nativa.
5. Si el permiso se deniega, se muestra un mensaje y la nota sigue funcionando.
6. Si el permiso queda denegado permanentemente, se ofrece abrir Ajustes mediante `openAppSettings()`.
7. Si el servicio de ubicacion esta apagado, se informa el estado y se permite continuar sin coordenadas.

La solicitud se realiza al momento de uso y no durante el arranque, reduciendo permisos innecesarios y permitiendo que el usuario entienda el motivo de cada solicitud.

## 6. Matriz de degradacion

| Situacion | Respuesta visible | Continuidad de la app | Evidencia para el video |
|---|---|---|---|
| Permiso concedido | Se abre la camara o se muestran coordenadas. | La nota incorpora la metadata obtenida. | Dialogo concedido y resultado en el editor. |
| Permiso denegado una vez | Mensaje explicando que la capacidad no se usara. | Se puede guardar una nota de texto. | Pulsar `No permitir` y guardar. |
| Denegacion permanente | Mensaje con opcion de abrir Ajustes. | La app no se cierra; se puede continuar sin la capacidad. | Pantalla de Ajustes y regreso a la app. |
| Servicio de ubicacion apagado | Mensaje de ubicacion no disponible. | La nota se guarda sin coordenadas. | Desactivar Ubicacion y repetir la accion. |
| Sin conectividad | Estado de red o mensaje de sincronizacion pendiente. | SQLite conserva notas y outbox. | Modo avion, guardar, recuperar red y sincronizar. |
| Backend no autenticado | Respuesta `401` y flujo de inicio de sesion. | La app solicita autenticacion y no expone datos privados. | Reiniciar sesion o mostrar la pantalla de acceso. |

## 7. Integracion con almacenamiento local y backend

La aplicacion utiliza un flujo local-first:

- SQLite conserva la cache de notas.
- El repositorio administra el estado local y la cola de operaciones pendientes.
- Las acciones se sincronizan con la API cuando existe conectividad y una sesion valida.
- La metadata de la capacidad usada se incorpora al contenido de la nota en el editor.
- Si la red falla, la nota no se pierde; queda disponible localmente para reintentar la sincronizacion.

La API expone autenticacion y operaciones de notas. En la prueba de conectividad realizada en el emulador se obtuvo `GET /api/notes -> 200` despues de conectar la app al backend.

## 8. Nivel de API objetivo

Configuracion Android del proyecto:

- **minSdk:** `flutter.minSdkVersion`, resuelto por Flutter como API 24.
- **targetSdk:** `flutter.targetSdkVersion`, resuelto por Flutter 3.47.0 como API 36.
- **compileSdk:** `flutter.compileSdkVersion`, resuelto por Flutter 3.47.0 como API 36.
- **Lenguaje Java/Kotlin:** Java 17 y JVM target 17.

El emulador usado durante la validacion fue Android 17, API 37. El objetivo de la aplicacion es API 36 y el dispositivo de prueba utiliza una version superior compatible.

## 9. Evidencias tecnicas

- `flutter analyze`: `No issues found!`
- `flutter test --reporter expanded`: `All tests passed!`
- APK release generado: `build/app/outputs/flutter-apk/app-release.apk`.
- APK preparado para telefono real: `baquero-notes-local.apk`.
- Ejecucion Android validada con instalacion y arranque en el emulador.
- Backend validado en la red local con Flask escuchando en `0.0.0.0:5000`.

## 10. Limitaciones y recomendaciones

- La prueba final solicitada debe grabarse en un telefono fisico, no solamente en el emulador.
- El APK local requiere que el telefono y el backend esten en la misma Wi-Fi.
- La IP `192.168.68.114` puede cambiar; si cambia, se debe generar nuevamente el APK con la nueva IP o usar un dominio.
- Para produccion se debe configurar HTTPS, una URL estable, un servidor WSGI y firma release con un keystore propio.
- El proyecto no contiene carpeta `ios/`; por eso este informe documenta los permisos Android demostrados.

## 11. Conclusion

Baquero Notes incorpora dos capacidades pertinentes del dispositivo, camara y ubicacion, con permisos solicitados en contexto, tratamiento de denegaciones temporales y permanentes, acceso directo a Ajustes, y continuidad mediante almacenamiento local. La integracion con el backend permite sincronizar las notas cuando vuelve la conectividad, sin convertir los permisos nativos en un requisito para usar la funcion basica de notas.

# Guion del video: capacidades nativas de Baquero Notes

## Datos de grabacion

- Duracion sugerida: 4 a 6 minutos.
- Dispositivo: telefono Android fisico.
- Aplicacion: Baquero Notes.
- Backend: equipo de desarrollo en la misma red Wi-Fi.
- URL usada en el APK local: `http://192.168.68.114:5000/api`.
- Recomendacion: activar la grabacion de pantalla y mostrar tambien los cuadros de dialogo del sistema.
- Antes de grabar: iniciar el backend, conectar el telefono y el PC a la misma Wi-Fi, y verificar que el telefono tenga bateria suficiente.

## Escena 1. Presentacion

**Mostrar:** pantalla inicial de la app.

**Decir:**

> Esta es Baquero Notes, una aplicacion de notas con almacenamiento local y sincronizacion con backend. En esta demostracion usare dos capacidades del dispositivo: camara y ubicacion. Ambas se solicitan solamente cuando el usuario intenta utilizarlas.

**Accion:** iniciar sesion o crear una cuenta de prueba.

## Escena 2. Integracion con backend y almacenamiento local

**Mostrar:** lista de notas vacia o con notas existentes.

**Decir:**

> La aplicacion consulta las notas del backend despues de iniciar sesion. La respuesta se conserva en SQLite local mediante el repositorio local-first. Esto permite continuar trabajando aunque la red falle.

**Accion:** crear una nota con titulo `Nota de prueba fisica` y contenido breve. Guardarla.

**Mostrar:** la nota aparece en la lista.

**Decir:**

> La nota se guarda localmente y se envia al backend cuando hay conectividad. La sincronizacion utiliza el repositorio y la cola de operaciones pendientes.

## Escena 3. Capacidad de camara con permiso concedido

**Accion:** abrir el editor de una nota o crear una nueva y pulsar `Foto`.

**Mostrar:** dialogo del sistema solicitando permiso de camara.

**Accion:** pulsar `Permitir` y tomar una fotografia. Confirmar la fotografia si el sistema lo solicita.

**Mostrar:** en el editor aparece el estado `Foto adjuntada: ...`.

**Decir:**

> El permiso de camara se solicita en el momento de uso. Con el permiso concedido, el selector nativo abre la camara. La aplicacion conserva la referencia informativa de la foto junto con la nota y no bloquea el resto del formulario.

**Accion:** guardar la nota y volver a abrirla para mostrar que el estado se conserva en el contenido local.

## Escena 4. Capacidad de ubicacion con permiso concedido

**Accion:** crear o editar una nota y pulsar `Ubicacion`.

**Mostrar:** dialogo del sistema solicitando ubicacion durante el uso.

**Accion:** pulsar `Permitir`.

**Mostrar:** el editor presenta `Ubicacion: latitud, longitud`.

**Decir:**

> La ubicacion se obtiene solamente despues de verificar que el servicio de ubicacion esta activo y que el permiso fue concedido. Las coordenadas se incorporan a la nota y se conservan en el flujo local-first.

**Accion:** guardar la nota y mostrarla en la lista.

## Escena 5. Denegacion temporal

**Preparacion:** ir a Ajustes del telefono, Aplicaciones, Baquero Notes, Permisos. Restablecer el permiso de camara o ubicacion, segun la prueba.

**Accion:** volver a la app, abrir el editor y pulsar la capacidad elegida. En el dialogo del sistema pulsar `No permitir`.

**Mostrar:** mensaje de la app indicando que la capacidad no esta disponible y que la nota puede guardarse sin imagen o sin coordenadas.

**Decir:**

> Cuando el usuario deniega el permiso, la aplicacion no se cierra ni bloquea el guardado. Informa la causa y degrada la funcionalidad: la nota continua disponible sin ese dato adicional.

**Accion:** guardar una nota sin la capacidad y mostrar que se guardo correctamente.

## Escena 6. Denegacion permanente y acceso a Ajustes

**Preparacion:** repetir la denegacion hasta que Android no vuelva a mostrar el dialogo, o bloquear manualmente el permiso desde Ajustes.

**Accion:** volver a Baquero Notes, pulsar `Foto` o `Ubicacion`.

**Mostrar:** mensaje de permiso bloqueado y, a continuacion, la pantalla de Ajustes del sistema abierta desde la app.

**Decir:**

> Cuando el sistema informa una denegacion permanente, la app ofrece abrir directamente los ajustes. El usuario puede habilitar el permiso sin tener que buscar manualmente la aplicacion. Si no lo habilita, la nota sigue funcionando sin la capacidad.

**Accion:** regresar a la app, conceder el permiso y repetir brevemente la capacidad para demostrar la recuperacion.

## Escena 7. Trabajo sin red y recuperacion

**Preparacion:** activar modo avion o desconectar el telefono de la Wi-Fi.

**Accion:** crear o editar una nota y guardarla.

**Mostrar:** la nota queda disponible localmente y el indicador de cambios pendientes, si aparece.

**Decir:**

> Sin red, el almacenamiento local mantiene la operacion y la deja pendiente de sincronizacion. Al recuperar la conectividad, el repositorio vuelve a intentar la sincronizacion con el backend.

**Accion:** desactivar modo avion, esperar la sincronizacion y actualizar la lista.

**Mostrar:** la nota disponible nuevamente desde el backend o sin cambios pendientes.

## Cierre

**Decir:**

> Se demostraron dos capacidades nativas, sus permisos concedidos, la denegacion temporal, la denegacion permanente con acceso a Ajustes, y la continuidad de la aplicacion con almacenamiento local y sincronizacion backend.

## Lista de tomas obligatorias

- [ ] Camara con permiso concedido.
- [ ] Ubicacion con permiso concedido.
- [ ] Una denegacion temporal visible.
- [ ] Una denegacion permanente y apertura de Ajustes.
- [ ] Nota guardada localmente sin red.
- [ ] Sincronizacion despues de recuperar la red.
- [ ] Nombre del proyecto y dispositivo fisico visibles al inicio o al cierre.

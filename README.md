# Baquero Notes

Aplicación Flutter de notas conectada a una API Flask segura. La interfaz se organiza mediante tokens de diseño, componentes reutilizables y estados explícitos de carga, vacío y error.

## Arquitectura

- `lib/design/`: tokens primitivos y semánticos, tipografía y tema Material 3.
- `lib/components/`: `AppButton`, `AppTextField`, `NoteCard` y `StatePanel`.
- `lib/screens/`: acceso, registro, notas y catálogo de componentes.
- `lib/api_service.dart`: autenticación JWT y CRUD; es el único módulo cliente que conoce las rutas.
- `backend/app.py`: API Flask, persistencia SQLite, validaciones, autorización y roles.
- `test/`: pruebas del contrato HTTP y de interfaz/semántica.
- `evidence/`: capturas responsivas generadas desde `app_preview.html` con los mismos tokens visuales.

## Endpoints consumidos por Flutter

| Método | Ruta | Pantalla |
|---|---|---|
| POST | `/api/auth/register` | Registro |
| POST | `/api/auth/login` | Acceso |
| POST | `/api/auth/logout` | Cierre de sesión |
| GET | `/api/notes` | Listado y actualización |
| POST | `/api/notes` | Editor: nueva nota |
| PUT | `/api/notes/{id}` | Editor: guardar cambios |
| DELETE | `/api/notes/{id}` | Confirmación de eliminación |

La API también ofrece renovación de token, exportación asíncrona y administración de usuarios; esos endpoints no tienen pantalla en esta entrega.

## Ejecución

1. Backend:

   ```bash
   cd backend
   python -m pip install -r requirements.txt
   python app.py
   ```

2. Flutter:

   ```bash
   flutter pub get
   flutter run
   ```

El emulador Android usa por defecto `http://10.0.2.2:5000/api`, configurable en `.env`.

## Pruebas

```bash
flutter test
```

El flujo del backend se verificó contra una base SQLite aislada: registro, creación, listado, actualización y eliminación. El entorno de elaboración no incluía Flutter SDK, por lo que las pruebas Dart quedan preparadas para ejecutarse en una estación con Flutter instalado.

## Accesibilidad

- Pares de color principales con contraste WCAG AA.
- Objetivos táctiles mínimos de 48 px.
- Etiquetas semánticas, `Tooltip` y regiones vivas.
- Los estados no dependen únicamente del color.
- Diseño desplazable y responsivo; la fuente del sistema no se limita.

## Repositorio remoto

Esta copia local no incluye metadatos Git ni una URL remota. Añada aquí el enlace de lectura antes de la entrega académica:

`[PENDIENTE: URL del repositorio GitHub/GitLab]`

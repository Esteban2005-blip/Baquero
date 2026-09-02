import os
import sqlite3
import json
import re
from datetime import datetime, timedelta
from functools import wraps
from flask import Flask, jsonify, request
from flask_jwt_extended import JWTManager, create_access_token, create_refresh_token, jwt_required, get_jwt_identity, get_jwt
from flask_cors import CORS
from flasgger import Swagger
import bcrypt
from dotenv import load_dotenv
from email_validator import validate_email, EmailNotValidError

# 🚀 OPTIMIZACIÓN 2: Importamos dependencias para Caché y Tareas Asíncronas
from flask_caching import Cache
import threading
import queue
import time

# Load environment variables
load_dotenv()

app = Flask(__name__)

# 🟢 OPTIMIZACIÓN 2: Configuración de Caché (Estrategia Cache-Aside)
cache = Cache(app, config={'CACHE_TYPE': 'SimpleCache', 'CACHE_DEFAULT_TIMEOUT': 60})

# Configure Flask-JWT-Extended
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)
app.config['JWT_REFRESH_TOKEN_EXPIRES'] = timedelta(days=30)
app.config['JSON_SORT_KEYS'] = False

jwt = JWTManager(app)
CORS(app)

# 🚀 OPTIMIZACIÓN 4: Configuración de Cola para Tareas Asíncronas
export_queue = queue.Queue()

def background_worker():
    while True:
        task = export_queue.get()
        if task is None: break
        user_id = task['user_id']
        # Simulación de operación costosa (ej. generar PDF)
        print(f"Iniciando exportación para el usuario {user_id}...")
        time.sleep(5)
        print(f"Exportación finalizada para el usuario {user_id}")
        export_queue.task_done()

# Iniciamos el worker en un hilo en segundo plano
threading.Thread(target=background_worker, daemon=True).start()

# ⚡ OPTIMIZACIÓN 6: Caché en memoria para Lista Negra de Tokens (Evita consultas a BD)
revoked_tokens_cache = set()

# Swagger configuration
swagger = Swagger(app, template={
    "swagger": "2.0",
    "info": {
        "title": "Secure Notes API",
        "version": "1.0.0",
        "description": "API segura para gestión de notas con autenticación JWT y control de roles"
    },
    "host": "localhost:5000",
    "basePath": "/api",
    "schemes": ["http", "https"],
    "securityDefinitions": {
        "Bearer": {
            "type": "apiKey",
            "name": "Authorization",
            "in": "header",
            "description": "JWT Authorization header using Bearer scheme"
        }
    }
})

DB_PATH = os.path.join(os.path.dirname(__file__), 'notes.db')

# Roles and permissions
ROLES = {
    'user': ['view_own_notes', 'create_notes', 'update_own_notes', 'delete_own_notes'],
    'admin': ['view_all_notes', 'create_notes', 'update_all_notes', 'delete_all_notes', 'manage_users']
}


def get_db():
    """Get database connection with row factory"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Initialize database tables"""
    conn = get_db()
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'user',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_active BOOLEAN DEFAULT 1
        )
    ''')
    
    # Create notes table with user_id and updated_at
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, title)
        )
    ''')
    
    # Create token blacklist for logout
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS token_blacklist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            jti TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP NOT NULL
        )
    ''')
    
    conn.commit()
    conn.close()


def clear_notes():
    """Clear all notes from database"""
    conn = get_db()
    conn.execute('DELETE FROM notes')
    conn.commit()
    conn.close()


def clear_users():
    """Clear all users from database"""
    conn = get_db()
    conn.execute('DELETE FROM users')
    conn.commit()
    conn.close()


# Password hashing utilities
def hash_password(password):
    """Hash password using bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def verify_password(password, password_hash):
    """Verify password against hash"""
    return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))


# Validation utilities
def validate_email_format(email):
    """Validate email format"""
    try:
        validate_email(email)
        return True
    except EmailNotValidError:
        return False


def validate_password(password):
    """
    Validate password strength
    Requirements: at least 8 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char
    """
    if len(password) < 8:
        return False, "La contraseña debe tener al menos 8 caracteres"
    
    if not re.search(r'[A-Z]', password):
        return False, "La contraseña debe contener al menos una mayúscula"
    
    if not re.search(r'[a-z]', password):
        return False, "La contraseña debe contener al menos una minúscula"
    
    if not re.search(r'[0-9]', password):
        return False, "La contraseña debe contener al menos un número"
    
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        return False, "La contraseña debe contener al menos un carácter especial"
    
    return True, "Contraseña válida"


# Authorization decorators
def role_required(required_role):
    """Decorator to check if user has required role"""
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            claims = get_jwt()
            user_role = claims.get('role', 'user')
            
            if user_role != required_role and user_role != 'admin':
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'INSUFFICIENT_PERMISSIONS',
                        'message': f'Se requiere rol {required_role}'
                    }
                }), 403
            
            return fn(*args, **kwargs)
        return wrapper
    return decorator


def permission_required(permission):
    """Decorator to check if user has specific permission"""
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            claims = get_jwt()
            user_role = claims.get('role', 'user')
            user_permissions = ROLES.get(user_role, [])
            
            if permission not in user_permissions:
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'INSUFFICIENT_PERMISSIONS',
                        'message': 'No tiene permiso para realizar esta acción'
                    }
                }), 403
            
            return fn(*args, **kwargs)
        return wrapper
    return decorator


@jwt.token_in_blocklist_loader
def check_if_token_revoked(jwt_header, jwt_data):
    """Check if token is in blacklist"""
    # ⚡ OPTIMIZACIÓN 6: Verificación en memoria (Evita consulta SQLite redundante en cada request)
    jti = jwt_data['jti']
    return jti in revoked_tokens_cache


@app.before_request
def setup_db():
    """Initialize database before each request"""
    init_db()


# Error handlers
@app.errorhandler(400)
def bad_request(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'BAD_REQUEST',
            'message': 'Solicitud inválida'
        }
    }), 400


@app.errorhandler(401)
def unauthorized(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'UNAUTHORIZED',
            'message': 'Usuario no autenticado'
        }
    }), 401


@app.errorhandler(403)
def forbidden(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'FORBIDDEN',
            'message': 'Sin permisos para realizar esta acción'
        }
    }), 403


@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'NOT_FOUND',
            'message': 'Recurso no encontrado'
        }
    }), 404


@app.errorhandler(405)
def method_not_allowed(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'METHOD_NOT_ALLOWED',
            'message': 'Método no permitido'
        }
    }), 405


@app.errorhandler(409)
def conflict(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'CONFLICT',
            'message': 'Conflicto con recurso existente'
        }
    }), 409


@app.errorhandler(422)
def unprocessable_entity(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'UNPROCESSABLE_ENTITY',
            'message': 'Entidad no procesable'
        }
    }), 422


@app.errorhandler(500)
def internal_server_error(error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'INTERNAL_SERVER_ERROR',
            'message': 'Error interno del servidor'
        }
    }), 500


# ==================== AUTHENTICATION ENDPOINTS ====================

@app.route('/api/auth/register', methods=['POST'])
def register():
    """
    Register a new user
    ---
    tags:
      - Authentication
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            email:
              type: string
              example: user@example.com
            password:
              type: string
              example: SecurePass123!
          required:
            - email
            - password
    responses:
      201:
        description: Usuario registrado exitosamente
      400:
        description: Datos inválidos o incompletos
      409:
        description: El email ya está registrado
    """
    payload = request.get_json(silent=True) or {}
    email = str(payload.get('email', '')).strip().lower()
    password = str(payload.get('password', ''))

    # Validate email
    if not email:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'El email es obligatorio'
            }
        }), 400

    if not validate_email_format(email):
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'El formato del email no es válido'
            }
        }), 400

    # Validate password
    if not password:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'La contraseña es obligatoria'
            }
        }), 400

    is_valid, message = validate_password(password)
    if not is_valid:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': message
            }
        }), 400

    # Check if user already exists
    conn = get_db()
    existing_user = conn.execute(
        'SELECT id FROM users WHERE email = ?',
        (email,)
    ).fetchone()

    if existing_user:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'DUPLICATE_EMAIL',
                'message': 'El email ya está registrado'
            }
        }), 409

    # Hash password and create user
    password_hash = hash_password(password)
    cursor = conn.execute(
        'INSERT INTO users (email, password_hash, role) VALUES (?, ?, ?)',
        (email, password_hash, 'user')
    )
    conn.commit()
    user_id = cursor.lastrowid

    # Create tokens
    access_token = create_access_token(
        identity=str(user_id),
        additional_claims={'email': email, 'role': 'user'}
    )
    refresh_token = create_refresh_token(identity=str(user_id))

    conn.close()

    return jsonify({
        'success': True,
        'message': 'Usuario registrado exitosamente',
        'data': {
            'user_id': user_id,
            'email': email,
            'role': 'user',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'token_type': 'Bearer',
            'expires_in': 3600
        }
    }), 201


@app.route('/api/auth/login', methods=['POST'])
def login():
    """
    Login user and return tokens
    ---
    tags:
      - Authentication
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            email:
              type: string
              example: user@example.com
            password:
              type: string
              example: SecurePass123!
          required:
            - email
            - password
    responses:
      200:
        description: Inicio de sesión exitoso
      400:
        description: Datos inválidos
      401:
        description: Credenciales incorrectas
    """
    payload = request.get_json(silent=True) or {}
    email = str(payload.get('email', '')).strip().lower()
    password = str(payload.get('password', ''))

    if not email or not password:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Email y contraseña son obligatorios'
            }
        }), 400

    # Find user
    conn = get_db()
    user = conn.execute(
        'SELECT id, email, password_hash, role FROM users WHERE email = ? AND is_active = 1',
        (email,)
    ).fetchone()
    conn.close()

    if not user or not verify_password(password, user['password_hash']):
        return jsonify({
            'success': False,
            'error': {
                'code': 'INVALID_CREDENTIALS',
                'message': 'Email o contraseña incorrectos'
            }
        }), 401

    # Create tokens
    access_token = create_access_token(
        identity=str(user['id']),
        additional_claims={'email': user['email'], 'role': user['role']}
    )
    refresh_token = create_refresh_token(identity=str(user['id']))

    return jsonify({
        'success': True,
        'message': 'Inicio de sesión exitoso',
        'data': {
            'user_id': user['id'],
            'email': user['email'],
            'role': user['role'],
            'access_token': access_token,
            'refresh_token': refresh_token,
            'token_type': 'Bearer',
            'expires_in': 3600
        }
    }), 200


@app.route('/api/auth/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh():
    """
    Refresh access token using refresh token
    ---
    tags:
      - Authentication
    security:
      - Bearer: []
    responses:
      200:
        description: Token renovado exitosamente
      401:
        description: Token de refresco inválido o expirado
    """
    user_id = int(get_jwt_identity())
    claims = get_jwt()
    
    conn = get_db()
    user = conn.execute(
        'SELECT id, email, role FROM users WHERE id = ? AND is_active = 1',
        (user_id,)
    ).fetchone()
    conn.close()

    if not user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'USER_NOT_FOUND',
                'message': 'Usuario no encontrado'
            }
        }), 401

    # Create new access token
    access_token = create_access_token(
        identity=str(user_id),
        additional_claims={'email': user['email'], 'role': user['role']}
    )

    return jsonify({
        'success': True,
        'message': 'Token renovado exitosamente',
        'data': {
            'access_token': access_token,
            'token_type': 'Bearer',
            'expires_in': 3600
        }
    }), 200


@app.route('/api/auth/logout', methods=['POST'])
@jwt_required()
def logout():
    """
    Logout user by blacklisting token
    ---
    tags:
      - Authentication
    security:
      - Bearer: []
    responses:
      200:
        description: Cierre de sesión exitoso
    """
    jti = get_jwt()['jti']
    exp = get_jwt()['exp']
    
    # ⚡ OPTIMIZACIÓN 6: Añadimos a la memoria RAM en lugar de la BD
    revoked_tokens_cache.add(jti)
    
    conn = get_db()
    conn.execute(
        'INSERT INTO token_blacklist (jti, expires_at) VALUES (?, datetime(?, "unixepoch"))',
        (jti, exp)
    )
    conn.commit()
    conn.close()

    return jsonify({
        'success': True,
        'message': 'Cierre de sesión exitoso'
    }), 200

@app.errorhandler(500)
def internal_server_error(_error):
    return jsonify({
        'success': False,
        'error': {
            'code': 'INTERNAL_SERVER_ERROR',
            'message': 'Error interno del servidor'
        }
    }), 500



# ==================== NOTES ENDPOINTS ====================

@app.route('/api/notes', methods=['POST'])
@jwt_required()
@permission_required('create_notes')
def create_note():
    """
    Create a new note for authenticated user
    ---
    tags:
      - Notes
    security:
      - Bearer: []
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            title:
              type: string
              example: Mi nota importante
            content:
              type: string
              example: Contenido de la nota
            createdAt:
              type: integer
              example: 1710000000000
    responses:
      201:
        description: Nota creada exitosamente
      400:
        description: Datos inválidos
      409:
        description: Ya existe una nota con ese título
    """
    user_id = int(get_jwt_identity())
    payload = request.get_json(silent=True) or {}
    title = str(payload.get('title', '')).strip()
    content = str(payload.get('content', '')).strip()
    created_at = payload.get('createdAt')

    # Validations
    if not title or len(title) < 3 or len(title) > 100:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'El título es obligatorio y debe tener entre 3 y 100 caracteres'
            }
        }), 400

    if not content or len(content) < 1 or len(content) > 5000:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'El contenido es obligatorio y debe tener máximo 5000 caracteres'
            }
        }), 400

    if created_at is None:
        created_at = int(__import__('time').time() * 1000)

    # Check for duplicate title for this user
    conn = get_db()
    existing = conn.execute(
        'SELECT id FROM notes WHERE user_id = ? AND LOWER(title) = LOWER(?)',
        (user_id, title)
    ).fetchone()

    if existing:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'DUPLICATE_TITLE',
                'message': 'Ya existe una nota con ese título'
            }
        }), 409

    # Create note
    cursor = conn.execute(
        'INSERT INTO notes (user_id, title, content, createdAt) VALUES (?, ?, ?, ?)',
        (user_id, title, content, created_at)
    )
    conn.commit()
    note_id = cursor.lastrowid
    row = conn.execute('SELECT id, user_id, title, content, createdAt FROM notes WHERE id = ?', (note_id,)).fetchone()
    conn.close()

    # 🟢 OPTIMIZACIÓN 2: Invalidación explícita del caché al crear una nota
    cache.delete(f'notes_user_{user_id}')
    cache.delete('notes_admin_all')

    return jsonify({
        'success': True,
        'message': 'Nota creada correctamente',
        'data': dict(row)
    }), 201


@app.route('/api/notes', methods=['GET'])
@jwt_required()
def list_notes():
    """
    List notes for authenticated user (or all if admin)
    ---
    tags:
      - Notes
    security:
      - Bearer: []
    parameters:
      - name: page
        in: query
        type: integer
        default: 1
      - name: limit
        in: query
        type: integer
        default: 10
    responses:
      200:
        description: Notas consultadas correctamente
    """
    user_id = int(get_jwt_identity())
    claims = get_jwt()
    user_role = claims.get('role', 'user')
    
    page = request.args.get('page', default=1, type=int)
    limit = request.args.get('limit', default=10, type=int)
    page = max(1, page)
    limit = max(1, min(limit, 50))

    # 🟢 OPTIMIZACIÓN 2: Revisar si existe en caché (Estrategia Cache-aside)
    cache_key = f'notes_admin_all_{page}_{limit}' if user_role == 'admin' else f'notes_user_{user_id}_{page}_{limit}'
    cached_response = cache.get(cache_key)
    if cached_response:
        return jsonify(cached_response), 200

    conn = get_db()
    
    # Admin can see all notes, user can only see their own
    # 🚀 OPTIMIZACIÓN 3 y 5: Eager Loading usando JOIN para traer el email sin causar consultas N+1
    if user_role == 'admin':
        total = conn.execute('SELECT COUNT(*) as total FROM notes').fetchone()['total']
        rows = conn.execute(
            '''SELECT notes.id, notes.user_id, users.email as author_email, notes.title, notes.content, notes.createdAt 
               FROM notes 
               JOIN users ON notes.user_id = users.id 
               ORDER BY notes.createdAt DESC LIMIT ? OFFSET ?''',
            (limit, (page - 1) * limit)
        ).fetchall()
    else:
        total = conn.execute('SELECT COUNT(*) as total FROM notes WHERE user_id = ?', (user_id,)).fetchone()['total']
        rows = conn.execute(
            '''SELECT notes.id, notes.user_id, users.email as author_email, notes.title, notes.content, notes.createdAt 
               FROM notes 
               JOIN users ON notes.user_id = users.id 
               WHERE notes.user_id = ? 
               ORDER BY notes.createdAt DESC LIMIT ? OFFSET ?''',
            (user_id, limit, (page - 1) * limit)
        ).fetchall()
    
    conn.close()

    response_data = {
        'success': True,
        'message': 'Notas consultadas correctamente',
        'data': [dict(row) for row in rows],
        'pagination': {
            'page': page,
            'limit': limit,
            'total': total
        }
    }
    
    # 🟢 OPTIMIZACIÓN 2: Guardar en caché el resultado (TTL por defecto 60s)
    cache.set(cache_key, response_data)

    return jsonify(response_data), 200


@app.route('/api/notes/<int:note_id>', methods=['GET'])
@jwt_required()
def get_note(note_id):
    """
    Get a specific note
    ---
    tags:
      - Notes
    security:
      - Bearer: []
    parameters:
      - name: note_id
        in: path
        type: integer
        required: true
    responses:
      200:
        description: Nota consultada correctamente
      403:
        description: No tiene permiso para ver esta nota
      404:
        description: Nota no encontrada
    """
    user_id = int(get_jwt_identity())
    claims = get_jwt()
    user_role = claims.get('role', 'user')
    
    conn = get_db()
    row = conn.execute('SELECT id, user_id, title, content, createdAt FROM notes WHERE id = ?', (note_id,)).fetchone()
    conn.close()

    if row is None:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NOT_FOUND',
                'message': 'La nota no existe'
            }
        }), 404

    # Authorization: user can only see own notes, admin can see all
    if user_role != 'admin' and row['user_id'] != user_id:
        return jsonify({
            'success': False,
            'error': {
                'code': 'FORBIDDEN',
                'message': 'No tiene permiso para ver esta nota'
            }
        }), 403

    return jsonify({
        'success': True,
        'message': 'Nota consultada correctamente',
        'data': dict(row)
    }), 200


@app.route('/api/notes/<int:note_id>', methods=['PUT'])
@jwt_required()
def update_note(note_id):
    """
    Update a note
    ---
    tags:
      - Notes
    security:
      - Bearer: []
    parameters:
      - name: note_id
        in: path
        type: integer
        required: true
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            title:
              type: string
            content:
              type: string
    responses:
      200:
        description: Nota actualizada correctamente
      403:
        description: No tiene permiso para actualizar esta nota
      404:
        description: Nota no encontrada
    """
    user_id = int(get_jwt_identity())
    claims = get_jwt()
    user_role = claims.get('role', 'user')
    
    payload = request.get_json(silent=True) or {}
    title = str(payload.get('title', '')).strip()
    content = str(payload.get('content', '')).strip()

    # Validations
    if not title or len(title) < 3 or len(title) > 100:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'El título es obligatorio y debe tener entre 3 y 100 caracteres'
            }
        }), 400

    if not content or len(content) < 1 or len(content) > 5000:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'El contenido es obligatorio y debe tener máximo 5000 caracteres'
            }
        }), 400

    conn = get_db()
    existing = conn.execute('SELECT id, user_id FROM notes WHERE id = ?', (note_id,)).fetchone()

    if existing is None:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'NOT_FOUND',
                'message': 'La nota no existe'
            }
        }), 404

    # Authorization: user can only update own notes, admin can update all
    if user_role != 'admin' and existing['user_id'] != user_id:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'FORBIDDEN',
                'message': 'No tiene permiso para actualizar esta nota'
            }
        }), 403

    # Check for duplicate title (excluding current note)
    duplicate = conn.execute(
        'SELECT id FROM notes WHERE user_id = ? AND LOWER(title) = LOWER(?) AND id != ?',
        (existing['user_id'], title, note_id)
    ).fetchone()

    if duplicate:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'DUPLICATE_TITLE',
                'message': 'Ya existe otra nota con ese título'
            }
        }), 409

    # Update note
    conn.execute(
        'UPDATE notes SET title = ?, content = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        (title, content, note_id)
    )
    conn.commit()
    row = conn.execute('SELECT id, user_id, title, content, createdAt FROM notes WHERE id = ?', (note_id,)).fetchone()
    conn.close()

    # 🟢 OPTIMIZACIÓN 2: Invalidación explícita del caché al actualizar
    cache.delete(f'notes_user_{user_id}')
    cache.delete('notes_admin_all')

    return jsonify({
        'success': True,
        'message': 'Nota actualizada correctamente',
        'data': dict(row)
    }), 200

# 🚀 OPTIMIZACIÓN 4: Tarea Asíncrona mediante Cola de Trabajo (Worker)
@app.route('/api/notes/export', methods=['POST'])
@jwt_required()
def export_notes_async():
    """
    Cola de Trabajo para Exportación Asíncrona
    """
    user_id = int(get_jwt_identity())
    
    # Enviamos el trabajo pesado al worker en segundo plano (no bloquea al cliente)
    export_queue.put({'user_id': user_id, 'action': 'export_pdf'})
    
    return jsonify({
        'success': True,
        'message': 'Su exportación ha comenzado. Le notificaremos cuando termine.'
    }), 202


@app.route('/api/notes/<int:note_id>', methods=['DELETE'])
@jwt_required()
def delete_note(note_id):
    """
    Delete a note
    ---
    tags:
      - Notes
    security:
      - Bearer: []
    parameters:
      - name: note_id
        in: path
        type: integer
        required: true
    responses:
      200:
        description: Nota eliminada correctamente
      403:
        description: No tiene permiso para eliminar esta nota
      404:
        description: Nota no encontrada
    """
    user_id = int(get_jwt_identity())
    claims = get_jwt()
    user_role = claims.get('role', 'user')
    
    conn = get_db()
    existing = conn.execute('SELECT id, user_id FROM notes WHERE id = ?', (note_id,)).fetchone()

    if existing is None:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'NOT_FOUND',
                'message': 'La nota no existe'
            }
        }), 404

    # Authorization: user can only delete own notes, admin can delete all
    if user_role != 'admin' and existing['user_id'] != user_id:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'FORBIDDEN',
                'message': 'No tiene permiso para eliminar esta nota'
            }
        }), 403

    conn.execute('DELETE FROM notes WHERE id = ?', (note_id,))
    conn.commit()
    conn.close()

    # 🟢 OPTIMIZACIÓN 2: Invalidación explícita del caché al eliminar
    cache.delete(f'notes_user_{user_id}')
    cache.delete('notes_admin_all')

    return jsonify({
        'success': True,
        'message': 'Nota eliminada correctamente'
    }), 200


# ==================== ADMIN ENDPOINTS ====================

@app.route('/api/admin/users', methods=['GET'])
@jwt_required()
@role_required('admin')
def list_users():
    """
    List all users (admin only)
    ---
    tags:
      - Admin
    security:
      - Bearer: []
    responses:
      200:
        description: Usuarios consultados correctamente
      403:
        description: No tiene permiso
    """
    page = request.args.get('page', default=1, type=int)
    limit = request.args.get('limit', default=10, type=int)
    page = max(1, page)
    limit = max(1, min(limit, 50))

    conn = get_db()
    total = conn.execute('SELECT COUNT(*) as total FROM users').fetchone()['total']
    rows = conn.execute(
        'SELECT id, email, role, is_active, created_at FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?',
        (limit, (page - 1) * limit)
    ).fetchall()
    conn.close()

    return jsonify({
        'success': True,
        'message': 'Usuarios consultados correctamente',
        'data': [dict(row) for row in rows],
        'pagination': {
            'page': page,
            'limit': limit,
            'total': total
        }
    }), 200


@app.route('/api/admin/users/<int:user_id>/role', methods=['PATCH'])
@jwt_required()
@role_required('admin')
def update_user_role(user_id):
    """
    Update user role (admin only)
    ---
    tags:
      - Admin
    security:
      - Bearer: []
    parameters:
      - name: user_id
        in: path
        type: integer
        required: true
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            role:
              type: string
              enum: [user, admin]
    responses:
      200:
        description: Rol actualizado correctamente
      403:
        description: No tiene permiso
      404:
        description: Usuario no encontrado
    """
    payload = request.get_json(silent=True) or {}
    role = str(payload.get('role', '')).strip().lower()

    if role not in ['user', 'admin']:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Rol inválido. Debe ser "user" o "admin"'
            }
        }), 400

    conn = get_db()
    user = conn.execute('SELECT id, email, role FROM users WHERE id = ?', (user_id,)).fetchone()

    if not user:
        conn.close()
        return jsonify({
            'success': False,
            'error': {
                'code': 'NOT_FOUND',
                'message': 'Usuario no encontrado'
            }
        }), 404

    conn.execute('UPDATE users SET role = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', (role, user_id))
    conn.commit()
    conn.close()

    return jsonify({
        'success': True,
        'message': 'Rol actualizado correctamente',
        'data': {
            'user_id': user_id,
            'email': user['email'],
            'role': role
        }
    }), 200


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

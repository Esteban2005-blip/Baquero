"""Secure Notes API. Run: python -m backend.app (from repository root)."""
import hashlib
import json
import os
import re
import secrets
import oracledb
import time
from datetime import timedelta
from functools import wraps
from pathlib import Path

import bcrypt
from dotenv import load_dotenv
from email_validator import EmailNotValidError, validate_email
from flask import Flask, g, jsonify, request
from flask_cors import CORS
from flask_jwt_extended import (JWTManager, create_access_token, create_refresh_token,
                                get_jwt, get_jwt_identity, jwt_required)
from werkzeug.exceptions import HTTPException



class OracleRow(dict):
    """Named JSON fields with positional access for aggregate queries."""
    def __getitem__(self, key):
        if isinstance(key, int):
            return list(self.values())[key]
        return super().__getitem__(key)


class OracleResult:
    def __init__(self, cursor, lastrowid=None):
        self.lastrowid = lastrowid
        self.rowcount = cursor.rowcount
        self.rows = []
        if cursor.description:
            names = [column[0] for column in cursor.description]
            for values in cursor.fetchall():
                self.rows.append(OracleRow(zip(names, [
                    value.read() if isinstance(value, oracledb.LOB) else value
                    for value in values])))
        self.position = 0

    def fetchone(self):
        if self.position >= len(self.rows):
            return None
        row = self.rows[self.position]
        self.position += 1
        return row

    def fetchall(self):
        rows = self.rows[self.position:]
        self.position = len(self.rows)
        return rows


class OracleDatabase:
    def __init__(self, connection):
        self.connection = connection

    def execute(self, sql, params=()):
        with self.connection.cursor() as cursor:
            lastrowid = None
            # Oracle identities are obtained with RETURNING, not SQLite lastrowid.
            if sql.startswith('INSERT INTO USUARIOS ') or sql.startswith('INSERT INTO NOTAS '):
                column = 'ID_USUARIO' if sql.startswith('INSERT INTO USUARIOS ') else 'ID_NOTA'
                out_id = cursor.var(oracledb.DB_TYPE_NUMBER)
                sql += f' RETURNING {column} INTO :new_id'
                binds = {str(i + 1): value for i, value in enumerate(params)}
                binds['new_id'] = out_id
                cursor.execute(sql, binds)
                lastrowid = int(out_id.getvalue()[0])
            else:
                cursor.execute(sql, params)
            return OracleResult(cursor, lastrowid)

    def commit(self):
        self.connection.commit()

    def rollback(self):
        self.connection.rollback()

    def close(self):
        try:
            self.connection.rollback()
        finally:
            self.connection.close()


def create_app(test_config=None):
    load_dotenv(Path(__file__).with_name('.env'))
    app = Flask(__name__)
    production = os.getenv('APP_ENV', 'development') == 'production'
    secret = os.getenv('JWT_SECRET_KEY')
    if production and (not secret or len(secret) < 32):
        raise RuntimeError('Production requires JWT_SECRET_KEY of at least 32 characters')
    app.config.update(
        JWT_SECRET_KEY=secret or secrets.token_urlsafe(48),
        JWT_ACCESS_TOKEN_EXPIRES=timedelta(seconds=int(os.getenv('ACCESS_TOKEN_SECONDS', '3600'))),
        JWT_REFRESH_TOKEN_EXPIRES=timedelta(days=30),
        ORACLE_USER=os.getenv('ORACLE_USER', 'BLOC_NOTAS_APP'),
        ORACLE_PASSWORD=os.getenv('ORACLE_PASSWORD'),
        ORACLE_HOST=os.getenv('ORACLE_HOST', 'localhost'),
        ORACLE_PORT=int(os.getenv('ORACLE_PORT', '1521')),
        ORACLE_SID=os.getenv('ORACLE_SID', 'orcl'),
        REQUIRE_HTTPS=production, MAX_CONTENT_LENGTH=64 * 1024,
    )
    if test_config:
        app.config.update(test_config)
    app.json.sort_keys = False
    CORS(app, resources={r'/api/*': {'origins': os.getenv(
        'CORS_ORIGINS', 'http://localhost:8080,http://127.0.0.1:8080').split(',')}})
    jwt = JWTManager(app)

    def db():
        if 'db' not in g:
            if not app.config['ORACLE_PASSWORD']:
                raise RuntimeError('Falta ORACLE_PASSWORD en backend/.env')
            connection = oracledb.connect(
                user=app.config['ORACLE_USER'],
                password=app.config['ORACLE_PASSWORD'],
                dsn=oracledb.makedsn(app.config['ORACLE_HOST'],
                    app.config['ORACLE_PORT'], sid=app.config['ORACLE_SID']))
            g.db = OracleDatabase(connection)
        return g.db

    @app.teardown_appcontext
    def close_db(_error):
        connection = g.pop('db', None)
        if connection is not None:
            connection.close()

    def error(code, message, status, fields=None):
        details = {'code': code, 'message': message}
        if fields:
            details['fields'] = fields
        return jsonify(success=False, error=details), status

    def validation(fields):
        return error('VALIDATION_ERROR', 'Revisa los campos indicados.', 422, fields)

    @app.before_request
    def enforce_https():
        # No trust in arbitrary X-Forwarded-Proto headers. TLS must be configured
        # on the WSGI server or through an explicitly trusted deployment proxy.
        if app.config['REQUIRE_HTTPS'] and not request.is_secure:
            return error('HTTPS_REQUIRED', 'Se requiere una conexión HTTPS.', 400)

    @app.after_request
    def security_headers(response):
        response.headers['Cache-Control'] = 'no-store'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        if app.config['REQUIRE_HTTPS']:
            response.headers['Strict-Transport-Security'] = 'max-age=31536000'
        return response

    @jwt.expired_token_loader
    def expired(_header, _payload):
        return error('TOKEN_EXPIRED', 'La sesión necesita renovarse.', 401)

    @jwt.invalid_token_loader
    def invalid(_reason):
        return error('INVALID_TOKEN', 'La credencial no es válida.', 401)

    @jwt.unauthorized_loader
    def missing(_reason):
        return error('UNAUTHORIZED', 'Inicia sesión para continuar.', 401)

    @jwt.revoked_token_loader
    def revoked(_header, _payload):
        return error('SESSION_EXPIRED', 'La sesión terminó. Vuelve a iniciar sesión.', 401)

    @jwt.token_in_blocklist_loader
    def revoked_session(_header, payload):
        session = db().execute('''SELECT s.ID_SESION FROM SESIONES s JOIN USUARIOS u ON u.ID_USUARIO=s.ID_USUARIO
            WHERE s.ID_SESION=:1 AND s.ID_USUARIO=:2 AND s.EXPIRA_EN>:3 AND u.ACTIVO=1''',
            (payload.get('sid'), payload['sub'], int(time.time()))).fetchone()
        return session is None

    @app.errorhandler(HTTPException)
    def http_error(exc):
        return error(f'HTTP_{exc.code}', 'No se pudo procesar la solicitud.', exc.code)

    @app.errorhandler(oracledb.IntegrityError)
    def constraint_error(_exc):
        db().rollback()
        return error('CONFLICT', 'El registro ya existe o fue modificado.', 409)

    @app.errorhandler(Exception)
    def unexpected(exc):
        if app.testing:
            raise exc
        app.logger.error('Unhandled API error: %s', type(exc).__name__)
        return error('INTERNAL_SERVER_ERROR', 'El servidor no pudo completar la operación.', 500)

    def body():
        value = request.get_json(silent=True)
        return value if isinstance(value, dict) else {}

    def current_user():
        return db().execute('SELECT ID_USUARIO AS "id", CORREO AS "email", PASSWORD_HASH AS "password_hash", ROL AS "role", ACTIVO AS "is_active", FECHA_REGISTRO AS "created_at" FROM USUARIOS WHERE ID_USUARIO=:1', (get_jwt_identity(),)).fetchone()

    def admin_required(fn):
        @wraps(fn)
        def wrapped(*args, **kwargs):
            if current_user()['role'] != 'admin':
                return error('FORBIDDEN', 'No tienes permiso para realizar esta acción.', 403)
            return fn(*args, **kwargs)
        return wrapped

    def session_data(user, sid, include_refresh=False):
        claims = {'sid': sid, 'email': user['email'], 'role': user['role']}
        data = dict(user_id=user['id'], email=user['email'], role=user['role'],
            access_token=create_access_token(identity=str(user['id']), additional_claims=claims),
            token_type='Bearer', expires_in=int(app.config['JWT_ACCESS_TOKEN_EXPIRES'].total_seconds()))
        if include_refresh:
            data['refresh_token'] = create_refresh_token(identity=str(user['id']), additional_claims={'sid': sid})
        return data

    def new_session(user):
        sid = secrets.token_urlsafe(32)
        db().execute('DELETE FROM SESIONES WHERE EXPIRA_EN<=:1', (int(time.time()),))
        db().execute('INSERT INTO SESIONES (ID_SESION,ID_USUARIO,EXPIRA_EN) VALUES (:1,:2,:3)', (sid, user['id'], int(time.time()) + 30 * 86400))
        db().commit()
        return session_data(user, sid, include_refresh=True)

    @app.get('/api/health')
    def health():
        db().execute('SELECT 1 FROM dual').fetchone()
        return jsonify(success=True, data={'status': 'ok', 'database': 'oracle'})

    @app.post('/api/auth/register')
    def register():
        payload = body()
        email, password = payload.get('email'), payload.get('password')
        fields = {}
        try:
            email = validate_email(email, check_deliverability=False).normalized.lower()
        except (EmailNotValidError, TypeError, AttributeError):
            fields['email'] = ['Introduce un correo electrónico válido.']
        if (not isinstance(password, str) or len(password) < 8 or len(password.encode('utf-8')) > 72 or
                not all(re.search(pattern, password) for pattern in (r'[A-Z]', r'[a-z]', r'[0-9]', r'[^\w\s]'))):
            fields['password'] = ['Usa al menos 8 caracteres, mayúscula, minúscula, número y símbolo; máximo 72 bytes.']
        if fields:
            return validation(fields)
        if db().execute('SELECT ID_USUARIO FROM USUARIOS WHERE CORREO=:1', (email,)).fetchone():
            return error('DUPLICATE_EMAIL', 'El correo ya está registrado.', 409, {'email': ['Este correo ya está registrado.']})
        name = payload.get('name')
        if name is not None and (not isinstance(name, str) or not 1 <= len(name.strip()) <= 100):
            return validation({'name': ['Usa entre 1 y 100 caracteres.']})
        payload['name'] = name.strip() if name is not None else email.split('@')[0][:100]
        password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
        cursor = db().execute('INSERT INTO USUARIOS (NOMBRE,CORREO,PASSWORD_HASH) VALUES (:1,:2,:3)', (payload.get('name') or email.split('@')[0], email, password_hash))
        db().commit()
        user = db().execute('SELECT ID_USUARIO AS "id", CORREO AS "email", PASSWORD_HASH AS "password_hash", ROL AS "role", ACTIVO AS "is_active", FECHA_REGISTRO AS "created_at" FROM USUARIOS WHERE ID_USUARIO=:1', (cursor.lastrowid,)).fetchone()
        return jsonify(success=True, data=new_session(user)), 201

    @app.post('/api/auth/login')
    def login():
        payload = body()
        email, password = payload.get('email'), payload.get('password')
        fields = {}
        if not isinstance(email, str) or not email.strip():
            fields['email'] = ['El correo es obligatorio.']
        if not isinstance(password, str) or not password or len(password.encode()) > 72:
            fields['password'] = ['Introduce una contraseña de hasta 72 bytes.']
        if fields:
            return validation(fields)
        user = db().execute('SELECT ID_USUARIO AS "id", CORREO AS "email", PASSWORD_HASH AS "password_hash", ROL AS "role", ACTIVO AS "is_active", FECHA_REGISTRO AS "created_at" FROM USUARIOS WHERE CORREO=:1 AND ACTIVO=1', (email.strip().lower(),)).fetchone()
        if not user or not bcrypt.checkpw(password.encode(), user['password_hash'].encode()):
            return error('INVALID_CREDENTIALS', 'Correo o contraseña incorrectos.', 401)
        return jsonify(success=True, data=new_session(user))

    @app.post('/api/auth/refresh')
    @jwt_required(refresh=True)
    def refresh():
        return jsonify(success=True, data=session_data(current_user(), get_jwt()['sid']))

    @app.post('/api/auth/logout')
    @jwt_required(verify_type=False)
    def logout():
        db().execute('DELETE FROM SESIONES WHERE ID_SESION=:1', (get_jwt()['sid'],))
        db().commit()
        return jsonify(success=True, message='Sesión cerrada.')

    def note_fields(payload):
        fields = {}
        for field, minimum, maximum in [('title', 3, 100), ('content', 1, 5000)]:
            value = payload.get(field)
            if not isinstance(value, str) or not minimum <= len(value.strip()) <= maximum:
                fields[field] = [f'Usa entre {minimum} y {maximum} caracteres.']
        created = payload.get('createdAt')
        if created is not None and (type(created) is not int or not 0 <= created <= 8640000000000000):
            fields['createdAt'] = ['La fecha debe expresarse en milisegundos válidos.']
        return fields

    def note_row(note_id):
        return db().execute('''SELECT n.ID_NOTA AS "id",n.ID_USUARIO AS "user_id",n.TITULO AS "title",n.CONTENIDO AS "content",n.FECHA_CREACION_MS AS "createdAt",u.CORREO AS "author_email"
            FROM NOTAS n JOIN USUARIOS u ON n.ID_USUARIO=u.ID_USUARIO WHERE n.ID_NOTA=:1''', (note_id,)).fetchone()

    def permitted_note(note_id):
        row = note_row(note_id)
        if row is None:
            return None, error('NOT_FOUND', 'La nota no existe.', 404)
        user = current_user()
        if row['user_id'] != user['id'] and user['role'] != 'admin':
            return None, error('FORBIDDEN', 'No tienes permiso para acceder a esta nota.', 403)
        return row, None

    @app.post('/api/notes')
    @jwt_required()
    def create_note():
        payload = body()
        fields = note_fields(payload)
        key = request.headers.get('Idempotency-Key')
        if key is not None and not re.fullmatch(r'[A-Za-z0-9_-]{8,128}', key):
            fields['client_id'] = ['Identificador de operación inválido.']
        if fields:
            return validation(fields)
        user_id = int(get_jwt_identity())
        title, content = payload['title'].strip(), payload['content'].strip()
        fingerprint = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        # Record and deduplication receipt commit atomically, even across workers.
        db().execute('SELECT ID_USUARIO FROM USUARIOS WHERE ID_USUARIO=:1 FOR UPDATE',
                     (user_id,)).fetchone()
        if key:
            receipt = db().execute('SELECT HUELLA AS "fingerprint", RESPUESTA AS "response" FROM IDEMPOTENCIA WHERE ID_USUARIO=:1 AND CLAVE=:2', (user_id, key)).fetchone()
            if receipt:
                db().rollback()
                if receipt['fingerprint'] != fingerprint:
                    return error('IDEMPOTENCY_CONFLICT', 'El identificador ya se usó con otros datos.', 409)
                return jsonify(success=True, data=json.loads(receipt['response'])), 201
        if db().execute('SELECT ID_NOTA FROM NOTAS WHERE ID_USUARIO=:1 AND LOWER(TITULO)=LOWER(:2)', (user_id, title)).fetchone():
            db().rollback()
            return error('DUPLICATE_TITLE', 'Ya existe una nota con ese título.', 409, {'title': ['El título ya está en uso.']})
        cursor = db().execute('INSERT INTO NOTAS (ID_USUARIO,TITULO,CONTENIDO,FECHA_CREACION_MS) VALUES (:1,:2,:3,:4)',
            (user_id, title, content, payload.get('createdAt') if payload.get('createdAt') is not None else int(time.time() * 1000)))
        data = dict(note_row(cursor.lastrowid))
        if key:
            data['client_id'] = key
            db().execute('INSERT INTO IDEMPOTENCIA (ID_USUARIO,CLAVE,HUELLA,RESPUESTA) VALUES (:1,:2,:3,:4)', (user_id, key, fingerprint, json.dumps(data)))
        db().commit()
        return jsonify(success=True, data=data), 201

    @app.get('/api/notes')
    @jwt_required()
    def list_notes():
        user = current_user()
        page = max(1, request.args.get('page', 1, type=int))
        limit = max(1, min(50, request.args.get('limit', 50, type=int)))
        where, args = ('', []) if user['role'] == 'admin' else ('WHERE n.ID_USUARIO=:1', [user['id']])
        total = db().execute(f'SELECT count(*) FROM NOTAS n {where}', args).fetchone()[0]
        rows = db().execute(f'''SELECT n.ID_NOTA AS "id",n.ID_USUARIO AS "user_id",n.TITULO AS "title",n.CONTENIDO AS "content",n.FECHA_CREACION_MS AS "createdAt",u.CORREO AS "author_email"
            FROM NOTAS n JOIN USUARIOS u ON n.ID_USUARIO=u.ID_USUARIO {where}
            ORDER BY n.FECHA_CREACION_MS DESC,n.ID_NOTA DESC OFFSET :offset_rows ROWS FETCH NEXT :limit_rows ROWS ONLY''', {**({'1': user['id']} if where else {}),
                'limit_rows': limit, 'offset_rows': (page - 1) * limit}).fetchall()
        return jsonify(success=True, data=[dict(row) for row in rows], pagination=dict(page=page, limit=limit, total=total))

    @app.get('/api/notes/<int:note_id>')
    @jwt_required()
    def get_note(note_id):
        row, failure = permitted_note(note_id)
        return failure if failure else jsonify(success=True, data=dict(row))

    @app.put('/api/notes/<int:note_id>')
    @jwt_required()
    def update_note(note_id):
        row, failure = permitted_note(note_id)
        if failure:
            return failure
        payload = body()
        fields = note_fields(payload)
        if fields:
            return validation(fields)
        db().execute('SELECT ID_USUARIO FROM USUARIOS WHERE ID_USUARIO=:1 FOR UPDATE',
                     (row['user_id'],)).fetchone()
        if db().execute('SELECT ID_NOTA FROM NOTAS WHERE ID_USUARIO=:1 AND LOWER(TITULO)=LOWER(:2) AND ID_NOTA!=:3',
                        (row['user_id'], payload['title'].strip(), note_id)).fetchone():
            db().rollback()
            return error('DUPLICATE_TITLE', 'Ya existe una nota con ese título.', 409, {'title': ['El título ya está en uso.']})
        db().execute('UPDATE NOTAS SET TITULO=:1,CONTENIDO=:2,FECHA_MODIFICACION=SYSTIMESTAMP WHERE ID_NOTA=:3',
                     (payload['title'].strip(), payload['content'].strip(), note_id))
        db().commit()
        return jsonify(success=True, data=dict(note_row(note_id)))

    @app.delete('/api/notes/<int:note_id>')
    @jwt_required()
    def delete_note(note_id):
        _row, failure = permitted_note(note_id)
        if failure:
            return failure
        db().execute('DELETE FROM NOTAS WHERE ID_NOTA=:1', (note_id,))
        db().commit()
        return jsonify(success=True, message='Nota eliminada.')

    @app.get('/api/admin/users')
    @jwt_required()
    @admin_required
    def list_users():
        rows = db().execute('SELECT ID_USUARIO AS "id",CORREO AS "email",ROL AS "role",ACTIVO AS "is_active",FECHA_REGISTRO AS "created_at" FROM USUARIOS ORDER BY ID_USUARIO').fetchall()
        return jsonify(success=True, data=[dict(row) for row in rows])

    @app.patch('/api/admin/users/<int:user_id>/role')
    @jwt_required()
    @admin_required
    def update_user_role(user_id):
        role = body().get('role')
        if role not in ('user', 'admin'):
            return validation({'role': ['Elige user o admin.']})
        cursor = db().execute('UPDATE USUARIOS SET ROL=:1,FECHA_MODIFICACION=SYSTIMESTAMP WHERE ID_USUARIO=:2', (role, user_id))
        db().commit()
        if not cursor.rowcount:
            return error('NOT_FOUND', 'El usuario no existe.', 404)
        return jsonify(success=True, data=dict(user_id=user_id, role=role))

    @app.post('/api/notes/export')
    @jwt_required()
    def export_notes():
        # The former worker only slept and promised a PDF it never generated.
        rows = db().execute('SELECT ID_NOTA AS "id",ID_USUARIO AS "user_id",TITULO AS "title",CONTENIDO AS "content",FECHA_CREACION_MS AS "createdAt" FROM NOTAS WHERE ID_USUARIO=:1',
                            (get_jwt_identity(),)).fetchall()
        response = jsonify(success=True, data=[dict(row) for row in rows])
        response.headers['Content-Disposition'] = 'attachment; filename=baquero-notes.json'
        return response

    return app


if __name__ == '__main__':
    create_app().run(host=os.getenv('HOST', '127.0.0.1'), port=int(os.getenv('PORT', '5000')), debug=False)

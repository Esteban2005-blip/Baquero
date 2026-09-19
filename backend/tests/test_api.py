from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
import secrets
import sqlite3

import pytest
from flask_jwt_extended import create_access_token, decode_token
from backend.app import create_app


@pytest.fixture
def app(tmp_path):
    return create_app({'TESTING': True, 'DATABASE': str(tmp_path / 'test.db'),
                       'JWT_SECRET_KEY': secrets.token_urlsafe(48)})


def register(client, email='ana@example.com'):
    response = client.post('/api/auth/register', json={'email': email, 'password': 'Test-Only123!'})
    assert response.status_code == 201, response.json
    return response.json['data']


def auth(session, refresh=False):
    return {'Authorization': 'Bearer ' + session['refresh_token' if refresh else 'access_token']}


def note(client, session, title='Nota de prueba', **kwargs):
    return client.post('/api/notes', headers=auth(session), json={'title': title, 'content': 'Texto', **kwargs})


def test_register_login_and_real_crud(app):
    c = app.test_client()
    s = register(c)
    login = c.post('/api/auth/login', json={'email': 'ANA@example.com', 'password': 'Test-Only123!'})
    assert login.status_code == 200
    response = note(c, s)
    assert response.status_code == 201
    data = response.json['data']
    assert data['user_id'] == s['user_id']
    assert isinstance(data['createdAt'], int)
    note_id = data['id']
    assert c.get('/api/notes', headers=auth(s)).json['data'][0]['id'] == note_id
    assert c.put(f'/api/notes/{note_id}', headers=auth(s), json={'title': 'Modificada', 'content': 'Nueva'}).status_code == 200
    # Previously stale cached lists hid changes for a full minute.
    assert c.get('/api/notes', headers=auth(s)).json['data'][0]['title'] == 'Modificada'
    assert c.delete(f'/api/notes/{note_id}', headers=auth(s)).status_code == 200
    assert c.get('/api/notes', headers=auth(s)).json['data'] == []


def test_expired_token_refresh_and_retry(app):
    c = app.test_client()
    s = register(c)
    with app.app_context():
        claims = decode_token(s['access_token'])
        expired = create_access_token(identity=str(s['user_id']), additional_claims={'sid': claims['sid']}, expires_delta=timedelta(seconds=-1))
    r = c.get('/api/notes', headers={'Authorization': 'Bearer ' + expired})
    assert r.status_code == 401 and r.json['error']['code'] == 'TOKEN_EXPIRED'
    refresh = c.post('/api/auth/refresh', headers=auth(s, True))
    assert refresh.status_code == 200
    assert 'refresh_token' not in refresh.json['data']  # Client retains the original refresh token.
    assert c.get('/api/notes', headers=auth(refresh.json['data'])).status_code == 200


def test_logout_revokes_refresh_across_app_restart(app):
    c = app.test_client()
    s = register(c)
    assert c.post('/api/auth/logout', headers=auth(s, True)).status_code == 200
    restarted = create_app(dict(app.config)).test_client()
    assert restarted.get('/api/notes', headers=auth(s)).status_code == 401
    assert restarted.post('/api/auth/refresh', headers=auth(s, True)).status_code == 401


@pytest.mark.parametrize('payload,fields', [
    ({}, {'title', 'content'}), ({'title': None, 'content': []}, {'title', 'content'}),
    ({'title': 'ab', 'content': 'x'}, {'title'}),
    ({'title': 'Valid', 'content': ''}, {'content'}),
    ({'title': 'Valid', 'content': 'ok', 'createdAt': 'yesterday'}, {'createdAt'}),
    ({'title': 'Valid', 'content': 'ok', 'createdAt': True}, {'createdAt'}),
])
def test_422_fields(app, payload, fields):
    c = app.test_client()
    s = register(c)
    r = c.post('/api/notes', headers=auth(s), json=payload)
    assert r.status_code == 422
    assert set(r.json['error']['fields']) == fields
    assert c.get('/api/notes', headers=auth(s)).json['pagination']['total'] == 0


@pytest.mark.parametrize('payload', [[], None, {'email': None, 'password': None},
    {'email': 'bad', 'password': 'weak'}, {'email': 'ok@example.com', 'password': 'A1!' + 'é' * 40}])
def test_invalid_registration_never_500(app, payload):
    assert app.test_client().post('/api/auth/register', json=payload).status_code == 422


def test_idempotency_replays_same_result_after_delete(app):
    c = app.test_client()
    s = register(c)
    headers = {**auth(s), 'Idempotency-Key': 'operation-12345678'}
    payload = {'title': 'Idempotente', 'content': 'Un registro', 'createdAt': 123}
    a = c.post('/api/notes', headers=headers, json=payload)
    b = c.post('/api/notes', headers=headers, json=payload)
    assert a.status_code == b.status_code == 201 and a.json == b.json
    assert c.get('/api/notes', headers=auth(s)).json['pagination']['total'] == 1
    c.delete(f"/api/notes/{a.json['data']['id']}", headers=auth(s))
    assert c.post('/api/notes', headers=headers, json=payload).json == a.json
    assert c.get('/api/notes', headers=auth(s)).json['pagination']['total'] == 0
    assert c.post('/api/notes', headers=headers, json={**payload, 'content': 'Changed'}).status_code == 409


def test_concurrent_creates_commit_once(app):
    s = register(app.test_client())
    def send(_):
        return app.test_client().post('/api/notes', headers={**auth(s), 'Idempotency-Key': 'parallel-12345678'},
            json={'title': 'Concurrente', 'content': 'Una sola nota'}).json
    with ThreadPoolExecutor(max_workers=4) as pool:
        responses = list(pool.map(send, range(4)))
    assert len({r['data']['id'] for r in responses}) == 1


def test_account_isolation_and_live_roles(app):
    c = app.test_client()
    a, b = register(c), register(c, 'bob@example.com')
    note_id = note(c, a).json['data']['id']
    assert c.get('/api/notes', headers=auth(b)).json['data'] == []
    for method in ['get', 'put', 'delete']:
        assert getattr(c, method)(f'/api/notes/{note_id}', headers=auth(b)).status_code == 403
    assert c.get('/api/admin/users', headers=auth(b)).status_code == 403
    with sqlite3.connect(app.config['DATABASE']) as db:
        db.execute('UPDATE users SET role="admin" WHERE id=?', (b['user_id'],))
    assert c.get('/api/notes', headers=auth(b)).json['pagination']['total'] == 1
    with sqlite3.connect(app.config['DATABASE']) as db:
        db.execute('UPDATE users SET role="user" WHERE id=?', (b['user_id'],))
    assert c.get('/api/admin/users', headers=auth(b)).status_code == 403


def test_pagination_and_duplicates(app):
    c = app.test_client()
    s = register(c)
    for i in range(55):
        assert note(c, s, title=f'Nota {i}', createdAt=1).status_code == 201
    a = c.get('/api/notes?limit=50&page=1', headers=auth(s)).json
    b = c.get('/api/notes?limit=50&page=2', headers=auth(s)).json
    assert len(a['data']) == 50 and len(b['data']) == 5
    assert not {r['id'] for r in a['data']} & {r['id'] for r in b['data']}
    assert note(c, s, title='NOTA 0').status_code == 409


def test_auth_contract_and_headers(app):
    c = app.test_client()
    for headers in [{}, {'Authorization': 'Bearer invalid'}]:
        r = c.get('/api/notes', headers=headers)
        assert r.status_code == 401 and r.json['error']['code']
        assert r.headers['Cache-Control'] == 'no-store'
    s = register(c)
    assert c.post('/api/auth/refresh', headers=auth(s)).status_code == 401
    assert c.get('/api/notes', headers=auth(s, True)).status_code == 401


def test_production_requires_secret_and_https(monkeypatch, tmp_path):
    monkeypatch.setenv('APP_ENV', 'production')
    monkeypatch.delenv('JWT_SECRET_KEY', raising=False)
    with pytest.raises(RuntimeError):
        create_app()
    monkeypatch.setenv('JWT_SECRET_KEY', secrets.token_urlsafe(48))
    c = create_app({'DATABASE': str(tmp_path / 'prod.db')}).test_client()
    assert c.get('/api/health').status_code == 400
    assert c.get('/api/health', headers={'X-Forwarded-Proto': 'https'}).status_code == 400
    r = c.get('/api/health', base_url='https://localhost')
    assert r.status_code == 200 and 'Strict-Transport-Security' in r.headers


def test_export_is_a_real_file(app):
    c = app.test_client()
    s = register(c)
    note(c, s)
    r = c.post('/api/notes/export', headers=auth(s))
    assert r.status_code == 200 and len(r.json['data']) == 1
    assert 'attachment' in r.headers['Content-Disposition']

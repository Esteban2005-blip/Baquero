"""Development-only API server with a 60-second token and redacted evidence.

Run from the repository root:
python tools/demo_server.py --database backend/demo.sqlite --events demo-events.jsonl
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import sys
import threading

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.app import create_app  # noqa: E402
from flask import request  # noqa: E402

parser = argparse.ArgumentParser()
parser.add_argument('--database', default='backend/demo.sqlite')
parser.add_argument('--events', default='demo-events.jsonl')
parser.add_argument('--port', type=int, default=5000)
args = parser.parse_args()
if os.getenv('APP_ENV', 'development') == 'production':
    raise SystemExit('This demo server is only for development.')
app = create_app({'DATABASE': args.database, 'JWT_ACCESS_TOKEN_EXPIRES': timedelta(seconds=60)})
lock = threading.Lock()


@app.after_request
def evidence(response):
    body = response.get_json(silent=True) or {}
    entry = {'time': datetime.now(timezone.utc).isoformat(), 'method': request.method,
             'path': request.path, 'status': response.status_code}
    if isinstance(body, dict) and isinstance(body.get('error'), dict):
        entry['error_code'] = body['error'].get('code')
        entry['field_names'] = list(body['error'].get('fields', {}))
    # Do not record headers, request bodies, tokens, email, passwords or notes.
    with lock, open(args.events, 'a', encoding='utf-8') as stream:
        stream.write(json.dumps(entry) + '\n')
    return response


app.run(host='127.0.0.1', port=args.port, debug=False)

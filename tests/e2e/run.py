import base64
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
COMPOSE = ['docker', 'compose', '-f', str(ROOT / 'compose.dev.yml')]
API_DB = 'postgres://postgres:local-development-only@db/everyday_trust_e2e'
WEB_DB = 'postgres://postgres:local-development-only@127.0.0.1:54329/everyday_trust_e2e'

def run(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, **kwargs)

def wait_until(predicate, process=None):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if process and process.poll() is not None:
            raise RuntimeError('Local test server stopped unexpectedly')
        try:
            if predicate():
                return
        except (OSError, ValueError):
            pass
        time.sleep(0.2)
    raise RuntimeError('Local test server did not become ready')

def healthy():
    with urllib.request.urlopen('http://localhost:4173/api/v1/health', timeout=2) as response:
        return response.status == 200

def main():
    for port in (4173,):
        with socket.socket() as probe:
            if probe.connect_ex(('127.0.0.1', port)) == 0:
                raise RuntimeError(f'Port {port} is in use; stop the project test server before running E2E')
    try:
        with urllib.request.urlopen('http://127.0.0.1:4000/api/v1/health', timeout=2):
            raise RuntimeError('An API is running on port 4000; stop it before running E2E')
    except (OSError, ConnectionError):
        pass
    run(['npm', 'run', 'build'])
    run(COMPOSE + ['exec', '-T', '-e', f'DATABASE_URL={API_DB}', 'api-dev', 'mix', 'ecto.setup'])
    with tempfile.TemporaryDirectory(prefix='trust-e2e-') as directory:
        jwks = Path(directory) / 'jwks.json'
        env = {**os.environ, 'NODE_ENV': 'test', 'E2E_IDENTITY_MOCK': 'true', 'E2E_JWKS_FILE': str(jwks),
               'API_BASE_URL': 'http://127.0.0.1:4000', 'API_SERVICE_TOKEN': 'local-development-service-token-only',
               'WEB_DATABASE_URL': WEB_DB, 'COGNITO_CLIENT_ID': 'qa-client',
               'COGNITO_ISSUER': 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_qa',
               'COGNITO_DOMAIN': 'https://everyday-trust-qa.auth.us-east-1.amazoncognito.com',
               'SESSION_ENCRYPTION_KEY': base64.b64encode(secrets.token_bytes(32)).decode(),
               'ORIGIN': 'http://localhost:4173', 'HOST': '127.0.0.1', 'PORT': '4173', 'SHUTDOWN_TIMEOUT': '1'}
        for name in ('COGNITO_CLIENT_SECRET', 'DATABASE_CA_FILE', 'WEB_MIGRATION_DATABASE_URL'):
            env.pop(name, None)
        run(['node', 'scripts/migrate-web.mjs'], env=env)
        web = subprocess.Popen(['node', '--import', './tests/e2e/oidc.mjs', 'build/index.js'], cwd=ROOT, env=env)
        api = None
        try:
            wait_until(jwks.exists, web)
            run(COMPOSE + ['cp', str(jwks), 'api-dev:/tmp/qa-jwks.json'])
            api = subprocess.Popen(COMPOSE + ['exec', '-T', '-e', f'DATABASE_URL={API_DB}',
                '-e', 'E2E_IDENTITY_MOCK=true', '-e', 'E2E_JWKS_FILE=/tmp/qa-jwks.json',
                '-e', 'PHX_SERVER=true',
                '-e', 'COGNITO_ISSUER=' + env['COGNITO_ISSUER'], '-e', 'COGNITO_CLIENT_ID=qa-client',
                'api-dev', 'mix', 'run', 'test/support/qa_server.exs'], cwd=ROOT)
            wait_until(healthy, api)
            run([os.environ.get('E2E_PYTHON', sys.executable), 'tests/e2e/browser.py'], env=env)
        finally:
            web.terminate()
            try:
                web.wait(timeout=5)
            except subprocess.TimeoutExpired:
                web.kill()
                web.wait()
            if api:
                subprocess.run(COMPOSE + ['exec', '-T', 'api-dev', 'sh', '-c',
                    'test ! -f /tmp/trust-e2e.pid || kill -TERM "$(cat /tmp/trust-e2e.pid)"'], cwd=ROOT)
                try:
                    api.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    api.terminate()

if __name__ == '__main__':
    main()

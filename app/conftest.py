import threading
import urllib.error
import urllib.request

import pytest


@pytest.fixture
def serve():
    """Start a server built by `factory(port=0, ...)` in a thread; return its base URL."""
    servers = []

    def _serve(factory, **kwargs):
        server = factory(port=0, **kwargs)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        servers.append(server)
        return f"http://127.0.0.1:{server.server_address[1]}"

    yield _serve
    for server in servers:
        server.shutdown()
        server.server_close()


def get(url: str) -> tuple[int, str]:
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode()

import sys
from pathlib import Path

sys.path[:0] = [str(Path(__file__).parent / "app1"), str(Path(__file__).parent / "app2")]

import importlib.util  # noqa: E402

from conftest import get  # noqa: E402


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).parent / name / "server.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


app1 = load("app1")
app2 = load("app2")


def test_app2_downstream(serve):
    base = serve(app2.make_server)
    assert get(f"{base}/api/downstream") == (200, "Hello from App2 (8082)")


def test_app2_healthz_and_404(serve):
    base = serve(app2.make_server)
    assert get(f"{base}/healthz")[0] == 200
    assert get(f"{base}/nope")[0] == 404


def test_fullchain_through_app2(serve):
    app2_base = serve(app2.make_server)
    base = serve(app1.make_server, app2_url=f"{app2_base}/api/downstream")
    assert get(f"{base}/api/fullchain") == (200, "App1 -> Hello from App2 (8082)")


def test_fullchain_app2_down_is_502(serve):
    base = serve(app1.make_server, app2_url="http://127.0.0.1:9/api/downstream")
    status, body = get(f"{base}/api/fullchain")
    assert status == 502
    assert body.startswith("App1 -> app2 unavailable")


def test_app1_hello_and_healthz(serve):
    base = serve(app1.make_server)
    assert get(f"{base}/api/hello") == (200, "Hello from App1 (8081)")
    assert get(f"{base}/healthz")[0] == 200

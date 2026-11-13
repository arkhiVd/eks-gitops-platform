"""app1: middle service. Calls app2. Ported from nginx-nlb-microservice-chain/userdata/app1.sh."""

import os
import socketserver
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8081"))
VERSION = os.environ.get("APP_VERSION", "dev")
APP2_URL = os.environ.get("APP2_URL", "http://app2:8082/api/downstream")
APP2_TIMEOUT = float(os.environ.get("APP2_TIMEOUT", "2"))


def call_app2(url: str = APP2_URL, timeout: float = APP2_TIMEOUT) -> tuple[int, str]:
    """Return (status, body). A failed downstream call is a 502, not a 200 with an error string."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:  # noqa: S310 (fixed in-cluster URL)
            return 200, "App1 -> " + resp.read().decode()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return 502, f"App1 -> app2 unavailable: {exc}"


class Server(ThreadingHTTPServer):
    """ThreadingHTTPServer without the reverse DNS lookup in server_bind.

    HTTPServer.server_bind calls socket.getfqdn() on the bind address, which blocks for the
    resolver timeout (5 s measured) when reverse DNS is slow. That delay lands on pod startup.
    """

    def server_bind(self) -> None:
        socketserver.TCPServer.server_bind(self)
        self.server_name = "localhost"
        self.server_port = self.server_address[1]


class Handler(BaseHTTPRequestHandler):
    server_version = "app1"
    app2_url = APP2_URL

    def _send(self, status: int, body: str) -> None:
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/api/hello"):
            self._send(200, f"Hello from App1 ({PORT})")
        elif self.path.startswith("/api/fullchain"):
            self._send(*call_app2(self.app2_url))
        elif self.path.startswith("/api/version"):
            self._send(200, VERSION)
        elif self.path == "/healthz":
            self._send(200, f"ok {VERSION}")
        else:
            self._send(404, "not found")

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} {fmt % args}", flush=True)


def make_server(port: int = PORT, app2_url: str = APP2_URL) -> Server:
    handler = type("BoundHandler", (Handler,), {"app2_url": app2_url})
    return Server(("0.0.0.0", port), handler)  # noqa: S104 (container listens on the pod IP)


if __name__ == "__main__":
    make_server().serve_forever()

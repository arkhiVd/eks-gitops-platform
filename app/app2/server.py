"""app2: last service in the chain. Ported from nginx-nlb-microservice-chain/userdata/app2.sh."""

import os
import socketserver
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("PORT", "8082"))
VERSION = os.environ.get("APP_VERSION", "dev")


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
    server_version = "app2"

    def _send(self, status: int, body: str) -> None:
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # noqa: N802 (http.server naming)
        if self.path.startswith("/api/downstream"):
            self._send(200, f"Hello from App2 ({PORT})")
        elif self.path == "/healthz":
            self._send(200, f"ok {VERSION}")
        else:
            self._send(404, "not found")

    def log_message(self, fmt: str, *args) -> None:
        # One line per request on stdout, no reverse DNS lookups.
        print(f"{self.address_string()} {fmt % args}", flush=True)


def make_server(port: int = PORT) -> Server:
    return Server(("0.0.0.0", port), Handler)  # noqa: S104 (container listens on the pod IP)


if __name__ == "__main__":
    make_server().serve_forever()

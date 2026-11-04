"""Serve a built QA app on loopback, failing instead of reusing another server."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--ready-file", type=Path)
    args = parser.parse_args()
    handler = partial(Handler, directory=args.directory)
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        if args.ready_file:
            args.ready_file.write_text(str(os.getpid()))
        server.serve_forever()


if __name__ == "__main__":
    main()

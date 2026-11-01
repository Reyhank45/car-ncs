import http.server
import urllib.request
import urllib.parse
import sys

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        
        if parsed.path == '/log':
            query = urllib.parse.parse_qs(parsed.query)
            msg = query.get('msg', [''])[0]
            sys.stderr.write(f"[BROWSER LOG] {msg}\n")
            sys.stderr.flush()
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b"ok")
            return

        target = f"https://ncs.io{self.path}"
        req = urllib.request.Request(target, headers={
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
            'Referer': 'https://ncs.io/',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        })
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
                sys.stderr.write(f"[Proxy] GET {self.path} -> {resp.status} ({len(data)} bytes)\n")
                sys.stderr.flush()
                self.send_response(resp.status)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', resp.headers.get('Content-Type', 'text/html'))
                self.end_headers()
                self.wfile.write(data)
        except Exception as e:
            sys.stderr.write(f"[Proxy Error] GET {self.path} -> {e}\n")
            sys.stderr.flush()
            self.send_response(502)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))

if __name__ == '__main__':
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 8088), ProxyHandler)
    print("CORS Proxy running on http://127.0.0.1:8088")
    server.serve_forever()

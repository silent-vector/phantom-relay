# Python3 HTTPS Server
import http.server
import ssl

# Define the handler and port
server_address = ('0.0.0.0', 6969)
httpd = http.server.HTTPServer(server_address, http.server.SimpleHTTPRequestHandler)

# Wrap the server with SSL
httpd.socket = ssl.wrap_socket(httpd.socket, certfile='./<file_name>.pem', server_side=True)

print(f"Serving on https://{server_address[0]}:{server_address[1]}")
httpd.serve_forever()

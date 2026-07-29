"""
app/main.py

Flask application entry point.

Run locally:
    python app/main.py

Or via Docker / docker-compose (see project root).
"""
import os
import sys

# Ensure the root directory is on sys.path so 'app' module can be found
_root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app import create_app

app = create_app()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    # Enable debug mode only when explicitly requested (e.g. FLASK_DEBUG=1).
    # Never enable debug in production – it exposes an interactive debugger.
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=port, debug=debug)

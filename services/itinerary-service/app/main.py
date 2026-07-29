"""itinerary-service/main.py — Entry point."""
import os
import sys

_root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app import create_app
from app.models import init_db

app = create_app()

if __name__ == "__main__":
    with app.app_context():
        init_db(app)
    port = int(os.environ.get("PORT", 5002))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=port, debug=debug)


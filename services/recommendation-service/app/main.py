"""recommendation-service/main.py — Entry point."""
import os
import sys

_root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app import create_app
from app.models import init_db
from app.overpass_sync import sync_destinations

app = create_app()

if __name__ == "__main__":
    # Initialize database and trigger initial Overpass sync
    with app.app_context():
        init_db(app)
        try:
            count = sync_destinations(app)
            print(f"Initial Overpass sync completed: {count} destinations")
        except Exception as e:
            print(f"Initial Overpass sync failed (will use cached data): {e}")

    port = int(os.environ.get("PORT", 5003))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=port, debug=debug)

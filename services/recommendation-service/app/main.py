"""recommendation-service/main.py — Entry point."""
import os
import sys
import threading

_root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app import create_app
from app.models import init_db
from app.foursquare_sync import sync_destinations, start_periodic_sync

app = create_app()


def _background_initial_sync(app):
    """Run the initial Foursquare sync in a background thread.

    This ensures the Flask server starts listening immediately,
    preventing 503 responses from the API gateway while the
    potentially long-running Foursquare call completes.
    """
    with app.app_context():
        try:
            stats, count = sync_destinations(app)
            print(
                f"Initial Foursquare sync completed: {count} destinations "
                f"({stats.get('total_venues', 0)} found, "
                f"{stats.get('kept', 0)} kept)"
            )
        except Exception as e:
            print(f"Initial Foursquare sync failed (will use cached data): {e}")

        # Start periodic background sync (every 12 hours)
        start_periodic_sync(app)


if __name__ == "__main__":
    # Initialize database tables immediately (fast, no network)
    with app.app_context():
        init_db(app)

    # Start initial Foursquare sync in background so server starts immediately
    sync_thread = threading.Thread(
        target=_background_initial_sync,
        args=(app,),
        daemon=True,
    )
    sync_thread.start()
    print("Background initial sync thread started. Server will be ready immediately.")

    port = int(os.environ.get("PORT", 5003))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=port, debug=debug, threaded=True)

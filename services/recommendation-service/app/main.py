"""recommendation-service/main.py — Entry point."""
import os
import sys

_root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from app import create_app
from app.models import init_db
from app.overpass_sync import sync_destinations


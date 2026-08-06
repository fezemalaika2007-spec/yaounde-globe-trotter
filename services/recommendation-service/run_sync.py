#!/usr/bin/env python3
"""Utility script to run the Foursquare sync once and print result."""
import sys
from app import create_app
from app.foursquare_sync import sync_destinations

def main():
    try:
        app = create_app()
        stats, count = sync_destinations(app)
        print(
            f"Synchronized {count} destinations from Foursquare "
            f"({stats.get('total_venues', 0)} found, "
            f"{stats.get('kept', 0)} kept, "
            f"{stats.get('excluded_no_photo', 0)} excluded no-photo)"
        )
        return 0
    except Exception as e:
        print(f"Sync failed: {e}", file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())

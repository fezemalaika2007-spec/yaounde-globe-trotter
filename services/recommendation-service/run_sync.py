#!/usr/bin/env python3
"""Utility script to run the Overpass sync once and print result."""
import sys
from app import create_app
from app.overpass_sync import sync_destinations

def main():
    try:
        app = create_app()
        count = sync_destinations(app)
        print(f"Synchronized {count} destinations")
        return 0
    except Exception as e:
        print(f"Sync failed: {e}", file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())

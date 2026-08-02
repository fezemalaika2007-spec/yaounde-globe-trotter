import sqlite3
import sys
import os
# Ensure project root is on sys.path so 'app' package can be imported
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if root not in sys.path:
    sys.path.insert(0, root)
from app import create_app

def main():
    app = create_app()
    db = app.config['DATABASE']
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    cur.execute("PRAGMA table_info(destinations)")
    cols = [r[1] for r in cur.fetchall()]
    if 'long_description' in cols:
        print('long_description already present')
    else:
        cur.execute("ALTER TABLE destinations ADD COLUMN long_description TEXT DEFAULT ''")
        conn.commit()
        print('long_description column added')
    conn.close()

if __name__ == '__main__':
    main()

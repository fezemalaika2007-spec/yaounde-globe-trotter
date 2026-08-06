"""Inspect description lengths in the DB."""
import sqlite3

conn = sqlite3.connect("database/recommendations.db")
conn.row_factory = sqlite3.Row
cur = conn.cursor()
cur.execute("SELECT name, description, long_description FROM destinations LIMIT 8")
for r in cur.fetchall():
    d = (r['description'] or '')
    ld = (r['long_description'] or '')
    print(f"name={r['name'][:30]!r} desc_len={len(d)} long_desc_len={len(ld)}")
    print(f"  desc: {d[:120]!r}")
    print(f"  long: {ld[:120]!r}")
conn.close()

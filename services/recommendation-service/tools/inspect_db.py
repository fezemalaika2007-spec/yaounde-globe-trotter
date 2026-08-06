"""Temporary diagnostic: inspect destination images and sources."""
import sqlite3

conn = sqlite3.connect("database/recommendations.db")
conn.row_factory = sqlite3.Row
cur = conn.cursor()

cur.execute("SELECT image_source, COUNT(*) c FROM destinations GROUP BY image_source")
print("== by source ==")
for r in cur.fetchall():
    print(f"  {r['image_source']}: {r['c']}")

cur.execute("SELECT COUNT(DISTINCT image) FROM destinations WHERE image != ''")
print("distinct primary images:", cur.fetchone()[0])

cur.execute("SELECT image, COUNT(*) c FROM destinations WHERE image != '' GROUP BY image ORDER BY c DESC LIMIT 8")
print("== top repeated images ==")
for r in cur.fetchall():
    print(f"  {r['c']}x  {r['image'][:100]}")

cur.execute("SELECT name, image, image_source, images FROM destinations LIMIT 5")
print("== sample rows ==")
for r in cur.fetchall():
    print(f"  name={r['name'][:30]!r} src={r['image_source']}")
    print(f"    image={r['image'][:90]!r}")
    print(f"    images={r['images'][:150]!r}")

cur.execute("SELECT name, image, image_source FROM destinations WHERE image_source != 'placeholder'")
print("== real-image destinations ==")
for r in cur.fetchall():
    print(f"  {r['image_source']:10s} {r['name'][:40]!r} {r['image'][:80]}")

conn.close()

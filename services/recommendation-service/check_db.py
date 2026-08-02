import sqlite3
import json
from app import create_app

def main():
    app = create_app()
    db_path = app.config['DATABASE']
    print('DB:', db_path)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute('SELECT count(*) as c FROM destinations')
    total = cur.fetchone()['c']
    print('Total destinations:', total)
    cur.execute('SELECT id, name, image, images, description, long_description FROM destinations LIMIT 10')
    rows = cur.fetchall()
    for r in rows:
        images = r['images'] or '[]'
        try:
            images_list = json.loads(images) if isinstance(images, str) else images
        except Exception:
            images_list = []
        unique = len(set(images_list))
        print('---')
        print('id:', r['id'])
        print('name:', r['name'])
        print('main image:', r['image'])
        print('images_count:', len(images_list), 'unique:', unique)
        print('images:', images_list)
        print('description:', (r['description'] or '')[:160])
        print('long_description:', (r['long_description'] or '')[:200])

if __name__ == '__main__':
    main()

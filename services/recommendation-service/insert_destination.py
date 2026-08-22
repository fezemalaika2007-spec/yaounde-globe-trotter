import os
import sys
import json
import uuid
import datetime

_root_dir = os.path.abspath(os.path.dirname(__file__))
if _root_dir not in sys.path:
    sys.path.insert(0, _root_dir)

from dotenv import load_dotenv
load_dotenv(os.path.join(_root_dir, "..", ".env"))

from app.models import get_connection, release_connection, clear_all_destinations

# The 11 image URLs provided in destinations.txt
IMAGE_URLS = [
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWn8hS7T1ZNlGLbk3XbjnKbd3zjVRiVPTyN8-YcxbKdXTLgN8rMUN-CoytwYCurjM4MGStnee4TJ6NMcrcn3UY1iu-D6nc5eJVRtGZW-icvKeH_i5Abd-IHp_j8ExqMItsnApx8hdQ=w450-h160-p-k-no",
    "https://www.google.com/maps/place/National+Museum/@3.8616357,11.5167199,17z/data=!3m1!4b1!4m6!3m5!1s0x108bcf84f791d633:0x56164fae3b22eac4!8m2!3d3.8616357!4d11.5167199!16s%2Fg%2F12z65blr2?entry=ttu&g_ep=EgoyMDI2MDgxOS4wIKXMDSoASAFQAw%3D%3D"
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWkPmYz2xUVhH7eg6q2DfEPfRMY4sgj_mGjD2J_RqIUWoARNeKRtREC2C-sO6H6eomwvWNgvzZTtTM3z6QLH2bzyY9zThkHge8Byvu7YIWKVpVs-bpcap499G2-uLib66me8W1g4=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmCXmjPzY6I1QMAAKAgdIeZ-A-0N1_fgVFEPvHWsBmG4LkYMsu-oPSKJoRUDhx3Nhh8Deje3AcJ4g425BpB93oF-cNFR5mxtIq0aunGWKR-56rlDHL-PPZHIn1f3bNfQJ3vI58=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWn6Qeed6FjSjrzbW7Td0Wk8DoNd2t3D2ZASCk-4li7bw0JDmTWO_YD0TiF3zXh-nGzIZq1Y7mHLCGLwBNGRorx_OuQMR5Z46_7A2X6wVDfss2JzyKpXm7CRNK_e-S6qBS8QGj9jUkyFC9Q=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWlpJLBOeJzAMyH9dtloUXVoZc4g6HJECmwt_a4tNvc_nm-46s1ifvU4zsthzjbY-a7qIQn2gs0VKIyAmfQhecL-9PRnmbmYN0cfGp42jQQAJhsDHAOLtjVK9VU1OprJdBUdeB8iJQ=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWmamKA5awf7wzdMy-qZa4hBhj9imJq74RCy9_XNcLBpDzl5BFVn2ASImvo3K-5u-YXKCrTu8ckgr6jC29bNwhGYh_0kNJWJKOLmRCiARjAnZ-mzzkJtdEEZh9N-5yWfPcw7AEpN=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWna7wgCb5vGfvfIcv2M0lVRjIrtSp1UrCI9yewaBs8hsk01jY8uSrwds10pEydAtMPrUbmS5yDZbgUURu4A9eDvIpzfzCip7Asa5AnF0TKZSs1QSpAKk0E2Mn9MQ2Nk4VzLVOga2A=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWkUqP9bXDHXHiqRApw2FD-LnOsDURe6srqVkf2yEzxnzSaxKL5Hr1Z7SVyIGSvDRrVym76EQgHRz52xVz9hDn4kju2veFGp9kKKwc_XGB73CpNRkZw709IM9oMtLimTUfhOJQ0=w450-h160-p-k-no",
    "https://lh3.googleusercontent.com/gps-cs-s/AHRPTWlqPnS9_D3RnsIcUWHCqaG_AJjHWErHmlRfc1ty5tmsrqWfx-iHflMkQGzZu2fslDq5COM4_K1D0AhE6BZIQXFPkGB8GzxSpVn7wvV4gIXfCUTLbi3t1OHk2tGHYmgNpnqHm-m2yg=w450-h160-p-k-no",
    "https://www.google.com/maps/search/Ebogo+Ecotourism+Yaounde/@3.5823257,11.471691,11z/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI2MDgxOS4wIKXMDSoASAFQAw%3D%3D"
]

# 11 distinct real tourist destinations in Yaoundé from Google Maps
DEST_INFOS = [
    {
        "name": "I Love My Country Cameroon Civic Monument",
        "category": "Culture & History",
        "desc": "Iconic civic monument landmark featuring a decorative patriotic sign, national colors, and night lighting located at central Carrefour Warda.",
        "activities": ["Photography", "Civic Walk", "Sightseeing"],
        "rating": 4.9, "count": 28,
        "gmaps": "https://www.google.com/maps/place/I+Love+My+Country+Cameroon+Round+About/@3.8661674,11.3834641,12z"
    },
    {
        "name": "National Museum of Yaoundé",
        "category": "Culture & History",
        "desc": "Housed in the former Governor's Palace, this premier national museum exhibits royal costumes, traditional instruments, sculptures, and historical relics of Cameroon's 250+ ethnic groups.",
        "activities": ["Museum Tour", "Cultural History", "Guided Viewing"],
        "rating": 4.8, "count": 34,
        "gmaps": "https://www.google.com/maps/place/National+Museum/@3.8616357,11.5167199,17z/data=!3m1!4b1!4m6!3m5!1s0x108bcf84f791d633:0x56164fae3b22eac4!8m2!3d3.8616357!4d11.5167199!16s%2Fg%2F12z65blr2?entry=ttu&g_ep=EgoyMDI2MDgxOS4wIKXMDSoASAFQAw%3D%3D"
    },
    {
        "name": "Reunification Monument (Monument de la Réunification)",
        "category": "Culture & History",
        "desc": "Monumental twin spiral sculpture constructed in 1973 symbolizing the historic 1961 unification of British Southern Cameroons and French Cameroun.",
        "activities": ["Historical Tour", "Architecture", "Photography"],
        "rating": 4.7, "count": 22,
        "gmaps": "https://www.google.com/maps/search/Reunification+Monument+Yaounde"
    },
    {
        "name": "Bois Sainte Anastasie Park & Botanical Garden",
        "category": "Nature & Parks",
        "desc": "Tranquil tropical urban park with paved shaded pathways, wooden bridges over streams, lush flowerbeds, and outdoor cafe dining.",
        "activities": ["Nature Walk", "Relaxation", "Picnic", "Garden Dining"],
        "rating": 4.7, "count": 19,
        "gmaps": "https://www.google.com/maps/search/Bois+Sainte+Anastasie+Yaounde"
    },
    {
        "name": "Cathédrale Notre Dame des Victoires",
        "category": "Culture & History",
        "desc": "Striking modern triangular cathedral consecrated in 1955, featuring impressive stained glass windows and seating for over 5,000 worshippers.",
        "activities": ["Architecture Viewing", "Spiritual Visit", "Photography"],
        "rating": 4.8, "count": 30,
        "gmaps": "https://www.google.com/maps/search/Cathedrale+Notre+Dame+des+Victoires+Yaounde"
    },
    {
        "name": "Mvog-Betsi Zoo & Wildlife Sanctuary",
        "category": "Nature & Parks",
        "desc": "Well-maintained wildlife sanctuary and primate rescue center housing drill monkeys, baboons, native birds, reptiles, and tropical flora.",
        "activities": ["Wildlife Viewing", "Guided Zoo Tour", "Family Walk"],
        "rating": 4.6, "count": 25,
        "gmaps": "https://www.google.com/maps/search/Mvog-Betsi+Zoo+Yaounde"
    },
    {
        "name": "Mont Fébé & Benedictine Monastery Viewpoint",
        "category": "Top Attractions",
        "desc": "Panoramic hilltop scenic lookout rising 1,070 meters above sea level, offering cool mountain breeze, lush views over all seven hills of Yaoundé, and the Benedictine museum.",
        "activities": ["Panoramic Viewing", "Sunset Watching", "Mountain Walk"],
        "rating": 4.9, "count": 40,
        "gmaps": "https://www.google.com/maps/search/Mont+Febe+Yaounde"
    },
    {
        "name": "Centre Artisanal de Yaoundé (Craft Market)",
        "category": "Shopping",
        "desc": "Vibrant artisan market display featuring handcrafted wood carvings, bronze statues, traditional Bamileke masks, beadwork, and local fabrics.",
        "activities": ["Handicraft Shopping", "Souvenir Browsing", "Cultural Crafts"],
        "rating": 4.5, "count": 17,
        "gmaps": "https://www.google.com/maps/search/Centre+Artisanal+de+Yaounde"
    },
    {
        "name": "Palais Polyvalent des Sports de Yaoundé (PAPOSY)",
        "category": "Top Attractions",
        "desc": "Modern multi-purpose indoor sports arena and cultural complex hosting international sporting matches, concerts, and national expos.",
        "activities": ["Sports Events", "Concerts", "City Landmark Tour"],
        "rating": 4.6, "count": 15,
        "gmaps": "https://www.google.com/maps/search/Palais+des+Sports+Yaounde"
    },
    {
        "name": "Basilique Marie-Reine-des-Apôtres de Mvolyé",
        "category": "Culture & History",
        "desc": "Masterpiece Marian minor basilica constructed on the historical site of Cameroon's first Catholic mission, famous for its grand architectural roof and stained glass.",
        "activities": ["Architecture", "Heritage Tour", "Photography"],
        "rating": 4.8, "count": 20,
        "gmaps": "https://www.google.com/maps/search/Basilique+Marie+Reine+des+Apotres+Mvolye"
    },
    {
        "name": "Ebogo Ecotourism Site & Nyong River Trail",
        "category": "Adventure",
        "desc": "Serene tropical ecotourism reserve offering traditional dugout canoe trips along the quiet Nyong River, century-old Entandrophragma trees, and jungle nature trails.",
        "activities": ["Canoeing", "Jungle Hiking", "Ecotourism", "Bird Watching"],
        "rating": 4.7, "count": 14,
        "gmaps": "https://www.google.com/maps/search/Ebogo+Ecotourism+Yaounde/@3.5823257,11.471691,11z/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI2MDgxOS4wIKXMDSoASAFQAw%3D%3D"
    }
]

def insert_all_11_destinations():
    clear_all_destinations()
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    conn = get_connection()
    cur = conn.cursor()

    inserted_ids = []
    for i, img_url in enumerate(IMAGE_URLS):
        dest_id = str(uuid.uuid4())
        info = DEST_INFOS[i]

        cur.execute("""
            INSERT INTO destinations (
                id, fsq_id, name, area, tags, description, long_description,
                cost, image, image_source, latitude, longitude, address,
                category, activities, opening_hours, website, average_rating,
                rating_count, star_rating, images, last_synced_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s
            )
        """, (
            dest_id,
            f"gmap-yaounde-dest-{i+1}",
            info["name"],
            "Yaoundé, Cameroon",
            json.dumps(["yaounde", "cameroon", info["category"].lower().replace(" ", "")]),
            info["desc"],
            info["desc"] + " Located in Yaoundé, Cameroon.",
            0.0,
            img_url,
            "google_maps",
            3.8661674,
            11.5153,
            "Yaoundé, Cameroon",
            info["category"],
            json.dumps(info["activities"]),
            "Open daily",
            info["gmaps"],
            info["rating"],
            info["count"],
            info["rating"],
            json.dumps([img_url]),
            now
        ))
        inserted_ids.append((dest_id, info["name"]))

    conn.commit()
    print(f"SUCCESS: Inserted {len(inserted_ids)} distinct Yaoundé destinations:")
    for dest_id, name in inserted_ids:
        print(f" - [{dest_id[:8]}] {name}")

    cur.close()
    release_connection(conn)

if __name__ == "__main__":
    insert_all_11_destinations()

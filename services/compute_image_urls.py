"""Compute actual Wikimedia Commons URLs for real Yaoundé images."""
import hashlib

def build_url(filename):
    safe_name = filename.replace(" ", "_")
    m = hashlib.md5(safe_name.encode("utf-8")).hexdigest()
    return f"https://upload.wikimedia.org/wikipedia/commons/{m[0]}/{m[0:2]}/{safe_name}"

# Best real Yaoundé images by category
images = {
    "general": [
        "The Star Building, Yaoundé, Cameroon.jpg",
        "Prime Minister Building, Yaoundé, Cameroon.jpg",
        "Yaoundé 1.jpg",
    ],
    "food": [
        "Restaurant Raphaelo - Odza, Yaoundé. 02.jpg",
        "Restaurant Raphaelo - Odza, Yaoundé. 04.jpg",
        "Bois Saint Anastasie - Yaoundé 02.jpg",
    ],
    "nature": [
        "Nature Yaoundé Cameroun.jpg",
        "Les Cascades du Mfoundi - Yaoundé 01.jpg",
        "Nature in Yaoundé.jpg",
        "Bananier à Yaoundé en novembre 1973.jpg",
    ],
    "market": [
        "Marché central - Central market (interior) in Yaoundé.JPG",
        "Cameroon Market(Yaoundé).jpg",
        "Street next to Central Market Yaoundé 2014.JPG",
        "Yaoundé view from central market (2014).JPG",
    ],
    "culture": [
        "YaoundeNationalMuseum.png",
        "MuséeNationalYaoundé.png",
        "BLackitude Museum.jpg",
        "Musée National Yaoundé.jpg",
    ],
    "accommodation": [
        "Hilton Hotel in Yaoundé (2014).JPG",
        "Hilton Hotel Yaoundé.JPG",
        "Hotel de ville Yaoundé Cameroun.jpg",
    ],
    "sports": [
        "YaoundeSportPalace.png",
        "Stade annex 1 de Yaoundé.jpg",
    ],
    "attraction": [
        "Monument Yaoundé.jpg",
        "Yaoundé vue monument 4.jpg",
        "Monument j'aime mon pays 03.jpg",
        "Bois Sainte Anastasie, Yaoundé, Cameroun.jpg",
    ],
}

for category, filenames in images.items():
    print(f"\n--- {category} ---")
    for fn in filenames:
        url = build_url(fn)
        print(f"  {url}")


import hashlib

def build_commons_url(filename):
    """Build a direct Wikimedia Commons image URL from a filename."""
    if not filename:
        return ""
    # Replace spaces with underscores
    safe_name = filename.replace(" ", "_")
    # Hash-based path for Commons URLs
    m = hashlib.md5(safe_name.encode("utf-8")).hexdigest()
    base_url = f"https://upload.wikimedia.org/wikipedia/commons/{m[0]}/{m[0:2]}/{safe_name}"
    return base_url

if __name__ == "__main__":
    # From the output of find_yaounde_images.py
    filenames = [
        "The Star Building, Yaoundé, Cameroon.jpg",
        "Prime Minister Building, Yaoundé, Cameroon.jpg",
        "Prime Minister Building Yaoundé, Cameroon.jpg",
        "Yaoundé 1.jpg",
        "1Place de l'indépendance hypodrome Yaoundé (2).jpg",
        "Marché central - Central market (interior) in Yaoundé.JPG",
        "Cameroon Market(Yaoundé).jpg",
        "Street next to Central Market Yaoundé 2014.JPG",
        "Yaoundé view from central market (2014).JPG",
        "Marché d'Ekounou (Yaoundé) (2).jpg",
        "Restaurant Raphaelo - Odza, Yaoundé. 02.jpg",
        "Restaurant Raphaelo - Odza, Yaoundé. 04.jpg",
        "Restaurant Raphaelo - Odza, Yaoundé. 03.jpg",
        "Restaurant Raphaelo - Odza, Yaoundé. 01.jpg",
        "Bois Saint Anastasie - Yaoundé 02.jpg",
        "Nature Yaoundé Cameroun.jpg",
        "Les Cascades du Mfoundi - Yaoundé 01.jpg",
        "Nature in Yaoundé.jpg",
        "Les Cascades du Mfoundi - Yaoundé 02.jpg",
        "Bananier à Yaoundé en novembre 1973.jpg",
        "Hilton Hotel in Yaoundé (2014).JPG",
        "Hilton Hotel Yaoundé.JPG",
        "Soccer Training in the Yaoundé town.jpg",
        "Monument j'aime mon pays 03.jpg",
        "Hotel de ville Yaoundé Cameroun.jpg",
        "Les benedictins1k.JPG",
        "YaoundeNationalMuseum.png",
        "MuséeNationalYaoundé.png",
        "BLackitude Museum.jpg",
        "Musée National Yaoundé.jpg",
        "1Place de l'indépendance hypodrome Yaoundé (10).jpg",
        "Yaoundé vue monument 4.jpg",
        "Monument Yaoundé.jpg",
        "1Place de l'indépendance hypodrome Yaoundé (7).jpg",
        "Entrance, Botanical Garden and Eco-Park, Sitakunda (01).jpg",
        "Boat in the Jamuna Bridge West Bank Eco-Park, Bangladesh.jpg",
        "Damas Yaoundé 4.jpg",
        "Bois Sainte Anastasie, Yaoundé, Cameroun.jpg",
        "Président de la FECAFOOT Samuel Eto'o et le Ministre de Sport Camerounais.jpg",
        "YaoundeSportPalace.png",
        "Charlotte Dipanda, Live Concert at Palais de Sport Yaoundé.JPG",
        "Stade annex 1 de Yaoundé.jpg",
        "Club mundi.jpg",
        "Overlook on the edge of Yaounde.jpg",
        "Les chutes de la lobé kribi cameroon1.jpg",
        "Flooding in Cameroon (MODIS 2022-09-13).jpg",
    ]

    urls = [build_commons_url(f) for f in filenames]
    
    # print as a python list
    print("[")
    for url in urls:
        print(f'    "{url}",')
    print("]")

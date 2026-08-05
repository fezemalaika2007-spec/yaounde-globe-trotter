
import requests
import time

def sync_and_check():
    """
    Triggers a sync and then checks for duplicate images.
    """
    try:
        print("Triggering sync...")
        response = requests.post("http://127.0.0.1:5003/sync-destinations")
        response.raise_for_status()
        print("Sync triggered successfully.")
    except requests.exceptions.RequestException as e:
        print(f"Error triggering sync: {e}")
        return

    print("Waiting for sync to complete...")
    time.sleep(60) # Wait for 1 minute for the sync to complete

    print("Checking for duplicate images...")
    try:
        response = requests.get("http://127.0.0.1:5003/destinations")
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching destinations: {e}")
        return

    destinations = response.json()

    image_urls = {}
    duplicates = {}

    for dest in destinations:
        for image_url in dest.get("images", []):
            if image_url in image_urls:
                if image_url not in duplicates:
                    duplicates[image_url] = [image_urls[image_url]]
                duplicates[image_url].append(dest["name"])
            else:
                image_urls[image_url] = dest["name"]

    if duplicates:
        print("Found duplicate images:")
        for url, dest_names in duplicates.items():
            try:
                print(f"  - URL: {url}")
                print(f"    Found in: {', '.join(dest_names)}")
            except UnicodeEncodeError:
                print(f"  - URL: {url.encode('utf-8')}")
                print(f"    Found in: {', '.join([name.encode('utf-8') for name in dest_names])}")
    else:
        print("No duplicate images found.")

if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    sync_and_check()

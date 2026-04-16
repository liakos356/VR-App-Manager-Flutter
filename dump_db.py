import sqlite3

def dump_urls(db_path):
    print("Dumping URLs from:", db_path)
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT name, video_url, trailer_url FROM apps")
        for row in cursor.fetchall():
            name, video, trailer = row
            if video or trailer:
                print(f"APP: {name}")
                print(f"VIDEO: {video}")
                print(f"TRAILER: {trailer}")
                print("---")
    except Exception as e:
        print(e)
        pass

dump_urls("/tmp/apps.db")

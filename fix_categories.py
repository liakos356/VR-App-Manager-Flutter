import os
import re

files = [
    'lib/screens/main_screen.dart',
    'lib/widgets/app_card.dart',
    'lib/widgets/app_detail_panel.dart'
]

for file_path in files:
    if not os.path.exists(file_path): continue
    with open(file_path, 'r') as f:
        content = f.read()

    # Replacing all category variables appropriately
    content = content.replace("app['categories'] ?? app['category'] ?? app['category']", "app['genres']")
    content = content.replace("app['category'] ?? app['categories']", "app['genres']")
    content = content.replace("app['categories'] ?? app['category']", "app['genres']")
    content = content.replace("All Categories", "All Genres")
    content = content.replace("_categoryFilter", "_genreFilter")
    content = content.replace("_availableCategories", "_availableGenres")
    content = content.replace("_getCategoryCount", "_getGenreCount")
    content = content.replace("matchesCategory", "matchesGenre")
    content = content.replace("category = ((app", "genre = ((app")
    content = content.replace("category.contains", "genre.contains")
    content = content.replace("Icons.category", "Icons.category") # leave this
    content = content.replace("label: 'Category',", "label: 'Genre',")

    # In app details / card
    content = content.replace("widget.app['category'] ?? widget.app['categories']", "widget.app['genres']")
    content = re.sub(r"widget\.app\[\'categories\'\]\s*\?\?\s*widget\.app\[\'category\'\]\s*\?\?\s*widget\.app\[\'category\'\]", "widget.app['genres']", content)
    content = re.sub(r"widget\.app\[\'categories\'\]\s*\?\?\s*widget\.app\[\'category\'\]", "widget.app['genres']", content)
    content = content.replace("app['category'] ?? ''", "app['genres'] ?? ''")
    
    with open(file_path, 'w') as f:
        f.write(content)

"""recommendation-service Flask application factory."""
import os
from pathlib import Path

from flask import Flask
from flask_cors import CORS


def create_app(config=None):
    """Create and configure the Recommendation Service Flask application."""
    app = Flask(__name__)
    CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)

    app.config["SECRET_KEY"] = os.environ.get(
        "SECRET_KEY", "globetrotter-secret-change-in-prod"
    )
    # Online PostgreSQL connection string (from env, never hardcoded).
    app.config["DATABASE"] = os.environ.get("DATABASE_URL", "")
    app.config["SQLITE_DATABASE_PATH"] = os.environ.get("SQLITE_DATABASE_PATH")
    app.config["COPY_SEED_DATABASE"] = os.environ.get("COPY_SEED_DATABASE", "1") != "0"
    app.config["CHAT_MEDIA_DIR"] = os.environ.get(
        "CHAT_MEDIA_DIR", str(Path(app.root_path).parent / "data" / "chat-media")
    )
    app.config["MAX_CONTENT_LENGTH"] = 25 * 1024 * 1024
    if config:
        app.config.update(config)

    from app.models import init_db, prepare_database
    prepare_database(app)
    init_db(app)
    Path(app.config["CHAT_MEDIA_DIR"]).mkdir(parents=True, exist_ok=True)

    from app.routes import recommendation_bp
    app.register_blueprint(recommendation_bp)
    from app.chat import chat_bp
    app.register_blueprint(chat_bp)

    return app

"""user-service Flask application factory."""
import os

from flask import Flask
from flask_cors import CORS

from app.models import init_db


def create_app():
    """Create and configure the User Service Flask application."""
    app = Flask(__name__)
    CORS(app)

    app.config["SECRET_KEY"] = os.environ.get(
        "SECRET_KEY", "globetrotter-secret-change-in-prod"
    )
    # Online PostgreSQL connection string (from env, never hardcoded).
    app.config["DATABASE"] = os.environ.get("DATABASE_URL", "")

    init_db(app)

    from app.routes import user_bp
    app.register_blueprint(user_bp)

    return app

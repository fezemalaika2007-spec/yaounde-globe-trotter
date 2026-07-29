"""recommendation-service Flask application factory."""
import os
from flask import Flask
from flask_cors import CORS


def create_app():
    """Create and configure the Recommendation Service Flask application."""
    app = Flask(__name__)
    CORS(app)

    app.config["SECRET_KEY"] = os.environ.get(
        "SECRET_KEY", "globetrotter-secret-change-in-prod"
    )
    app.config["DATABASE"] = os.environ.get(
        "DATABASE_PATH",
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "database", "recommendations.db")
    )

    from app.routes import recommendation_bp
    app.register_blueprint(recommendation_bp)

    return app

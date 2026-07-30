"""
api-gateway/app/__init__.py

API Gateway — single public entry point for all microservices.

This gateway contains NO business logic. It simply proxies requests
to the appropriate backend service based on the request path.
"""
import os
from flask import Flask
from flask_cors import CORS


def create_app():
    """Create and configure the API Gateway application."""
    app = Flask(__name__)
    CORS(app)

    # Register the proxy routes blueprint
    from app.routes import gateway_bp
    app.register_blueprint(gateway_bp)

    return app


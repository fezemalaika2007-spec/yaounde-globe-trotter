# Recommendation Service

The **Recommendation Service** provides intelligent place discovery, Foursquare API integration, rating & review aggregation, auto-seeding of rich Yaoundé destinations, and personalized matching.

## Port & Base Endpoint
- **Port**: `5003`
- **Base URL**: `http://localhost:5003`

## Key Capabilities
- **Preference & Ranking Engine**: Matches destinations based on user interest tags, rating counts, average ratings, and category filters (Nature, Culture, Dining, Shopping, Adventure).
- **Auto-Seeding**: Automatically populates 7 detailed default Yaoundé destinations with high-resolution Unsplash photo galleries, coordinates, and real descriptions if the database table is empty on startup.
- **Foursquare Sync Integration**: Live venue search and fallback synchronization via Foursquare Places API.
- **Database Connection Pooling**: Built with `ThreadedConnectionPool` (1-15 connections) and `release_connection` safety wrappers.
- **SQL Indexes**: Includes `idx_destinations_fsq_id` and `idx_ratings_dest_user`.

## API Routes
- `GET /destinations`: Returns filtered destinations by tag or max cost.
- `GET /search?q=<query>`: Live internet search for places in Yaoundé matching user search terms.
- `GET /recommendations`: Returns structured recommendation sections (`most_popular`, `highly_rated`, `recently_added`, `less_costly`, `food_markets`, `nature_parks`) for the user.
- `POST /destinations/<id>/rating`: Submits or updates a 1-5 star user rating.

## Running Locally & Testing

```bash
# Run service
pip install -r requirements.txt
python run.py

# Run test suite
python -m pytest
```

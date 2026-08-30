# Recommendation Service

The **Recommendation Service** provides intelligent place discovery, Foursquare API integration, 1–5 star rating submissions, threaded community discussions & replies, feedback/bug report management, user notifications, and destination parsing/synchronization.

## Port & Base Endpoint
- **Port**: `5003`
- **Base URL**: `http://localhost:5003`

## Key Capabilities
- **Preference & Ranking Engine**: Matches destinations based on user interest tags, rating counts, average ratings, and category filters (Nature & Parks, Culture & History, Food & Dining, Shopping, Nightlife & Entertainment, Entertainment & Amusement, Leisure & Wellness, Health & Pharmacy, Travel & Transport, Nature & Adventure).
- **Destinations Synchronization**: Automatically parses `destinations.txt` and syncs real place descriptions, exact addresses, opening hours, phone numbers, website links, facilities, activities, and prices in FCFA.
- **Threaded Community Comments**: Supports top-level destination reviews, author comment updates (`PUT`), cascading deletion (`DELETE`), and nested reply threads with real-time notification alerts.
- **Notifications System**: In-app notification center tracking replies, ratings, and travel updates with unread counts and batch mark-as-read endpoints.
- **Feedback & Bug Reporting**: Direct user support channel for suggestions, issues, and bug submissions open to all authenticated users.
- **Database Connection Pooling**: Built with `ThreadedConnectionPool` (1–15 connections) and `release_connection` safety wrappers.
- **SQL Indexes**: Includes `idx_destinations_fsq_id`, `idx_ratings_dest_user`, `idx_comments_dest`, `idx_comments_parent`, and `idx_notifications_user`.

## API Routes

### Destinations & Recommendations
- `GET /destinations`: Returns all destinations, with optional category, tag, or price filters.
- `GET /destinations/<dest_id>`: Returns full metadata for a specific destination.
- `GET /search?q=<query>`: Live place search matching user query terms.
- `GET /recommendations`: Returns structured recommendation sections (`most_popular`, `highly_rated`, `recently_added`, `less_costly`, `food_markets`, `nature_parks`) tailored to user profile interests.
- `POST /destinations/<id>/rating`: Submits or updates a 1–5 star rating for a destination (JWT required).
- `GET /destinations/<id>/user-rating`: Fetches the current authenticated user's rating for a destination.

### Community Comments & Replies
- `GET /destinations/<dest_id>/comments`: Returns all comments and threaded replies for a destination.
- `POST /destinations/<dest_id>/comments`: Adds a new comment or threaded reply (accepts optional `parent_id`, JWT required).
- `PUT /destinations/<dest_id>/comments/<comment_id>`: Updates an existing comment (author only, JWT required).
- `DELETE /destinations/<dest_id>/comments/<comment_id>`: Deletes a comment and its associated child replies (author only, JWT required).

### Notifications
- `GET /notifications`: Lists all notifications for the authenticated user.
- `GET /notifications/unread-count`: Returns the total count of unread notifications.
- `POST /notifications/<notif_id>/read`: Marks a single notification as read.
- `POST /notifications/read-all`: Marks all notifications for the authenticated user as read.

### Feedback & Support
- `POST /feedback`: Submits a feedback report or bug inquiry (JWT required).
- `GET /feedback`: Retrieves all submitted feedback entries (JWT required, open access to all authenticated users).
- `POST /feedback/<feedback_id>/resolve`: Marks a feedback ticket as resolved (JWT required, open access to all authenticated users).

## Running Locally & Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Run service
python run.py

# Sync destinations from destinations.txt
python parse_and_sync_destinations.py

# Run test suite
python -m pytest
```

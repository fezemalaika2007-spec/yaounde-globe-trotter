# Recommendation & Live Chat Service

The **Recommendation & Live Chat Service** is a core Python Flask microservice providing intelligent place discovery, Foursquare API integration, 1–5 star rating submissions, threaded destination comments, real-time global community chat API, direct email feedback dispatching, and automated SQLite destination database synchronization.

## Port & Base Endpoint
- **Port**: `5003`
- **Base URL**: `http://127.0.0.1:5003`

---

## Key Capabilities

- 💬 **Live Global Community Chat API**:
  - `GET /chat/messages`: Retrieves historical chat messages sorted chronologically.
  - `POST /chat/messages`: Posts new chat messages with support for custom display names, photo attachments, video links, emojis, stickers, and quote reply references (`reply_to_id`).
  - `PUT /chat/messages/<message_id>`: Updates existing chat message content (author verification).
  - `DELETE /chat/messages/<message_id>`: Deletes chat messages (author verification).
  - Guest-friendly `@optional_token` decorator supporting both authenticated JWT users and guest users with custom display aliases.
- ✉️ **Direct Email Feedback Dispatcher**:
  - `POST /feedback`: Receives feedback tickets from users, formats structured issue reports, and triggers background dispatch to developer `fezemalaika2007@gmail.com` via FormSubmit and SMTP email worker threads.
- 🎯 **Preference & Ranking Engine**: Matches destinations based on user interest tags, rating counts, average ratings, and category filters (Nature & Parks, Culture & History, Food & Dining, Shopping, Nightlife & Entertainment, Entertainment & Amusement, Leisure & Wellness, Health & Pharmacy, Travel & Transport, Nature & Adventure).
- 🔄 **Destinations Database Synchronization**: Automatically parses `destinations.txt` into local SQLite `destinations.db`, populating detailed venue metadata, address strings, opening hours, direct calling numbers (`tel:`), website URLs, and prices in FCFA.
- 💬 **Threaded Destination Comments**: Supports top-level destination reviews, comment updates (`PUT`), cascading deletion (`DELETE`), and nested reply threads with notification alerts.
- 🔔 **In-App Notifications**: Notification center tracking replies, ratings, and updates with unread counts and batch mark-as-read endpoints.

---

## API Routes Summary

### Live Community Chat
- `GET /chat/messages` — Fetch recent global community chat history.
- `POST /chat/messages` — Send a new chat message (supports photo attachments, video links, emojis, stickers, and reply quotes).
- `PUT /chat/messages/<message_id>` — Edit a previously sent chat message.
- `DELETE /chat/messages/<message_id>` — Delete a chat message.

---

### Destinations & Recommendations
- `GET /destinations` — Returns all destinations with optional category, tag, or price filters.
- `GET /destinations/<dest_id>` — Returns full metadata for a specific destination.
- `GET /search?q=<query>` — Live place search matching user query terms.
- `GET /recommendations` — Returns structured recommendation sections (`most_popular`, `highly_rated`, `recently_added`, `less_costly`, `food_markets`, `nature_parks`).
- `POST /destinations/<id>/rating` — Submits or updates a 1–5 star rating for a destination (JWT required).
- `GET /destinations/<id>/user-rating` — Fetches authenticated user's rating for a destination.

---

### Destination Comments & Replies
- `GET /destinations/<dest_id>/comments` — Returns all comments and threaded replies for a destination.
- `POST /destinations/<dest_id>/comments` — Adds a new comment or threaded reply (JWT required).
- `PUT /destinations/<dest_id>/comments/<comment_id>` — Updates an existing comment (author only, JWT required).
- `DELETE /destinations/<dest_id>/comments/<comment_id>` — Deletes a comment and its child replies (author only, JWT required).

---

### Notifications
- `GET /notifications` — Lists all notifications for authenticated user.
- `GET /notifications/unread-count` — Returns count of unread notifications.
- `POST /notifications/<notif_id>/read` — Marks a single notification as read.
- `POST /notifications/read-all` — Marks all notifications for user as read.

---

### Feedback & Developer Support
- `POST /feedback` — Submits feedback/bug report and triggers email dispatch to `fezemalaika2007@gmail.com`.

---

## Running Locally & Testing

```bash
# Install dependencies
pip install -r requirements.txt

# Run recommendation & chat service
python app/main.py

# Sync destinations from destinations.txt to local SQLite database
python parse_and_sync_destinations.py

# Run test suite
python -m pytest
```


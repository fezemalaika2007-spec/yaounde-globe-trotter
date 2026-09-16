# Recommendation & Live Chat Service

The **Recommendation & Live Chat Service** is a core Python Flask microservice providing intelligent place discovery, Foursquare API integration, 1–5 star rating submissions, threaded destination comments, real-time global community chat API, direct email feedback dispatching, and automated SQLite destination database synchronization.

## Port & Base Endpoint
- **Port**: `5003`
- **Base URL**: `http://127.0.0.1:5003`

---

## Key Capabilities

- 💬 **Live Global Community Chat API**:
  - `GET /chat/messages`: Retrieves historical chat messages sorted chronologically.
  - `POST /chat/messages`: Posts text, uploaded photos/videos, emojis, stickers, and quote reply references (`reply_to_id`). The sender comes from the verified JWT, not a client-supplied name.
  - `PUT /chat/messages/<message_id>`: Updates existing chat message content (author verification).
  - `DELETE /chat/messages/<message_id>`: Deletes chat messages (author verification).
  - Anyone can read; posting, uploading, editing, and deleting require a valid JWT.
  - `POST /chat/uploads`: Accepts one multipart `file`, up to 20 MB. Supported types are JPEG, PNG, GIF, WebP, MP4, and WebM.
  - `GET /chat/media/<filename>`: Serves uploaded media publicly, including HTTP Range/206 responses for video playback.
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
- `POST /chat/uploads` — Upload media first, then pass the returned `media_url` and `media_type` to the message endpoint.
- `GET /chat/media/<filename>` — Read or stream an attachment.

All readers share the same conversation. `GET /chat/messages` initially returns
the latest 100 messages, with `limit` capped at 100 per request. To load an older
page, pass both `before_created_at` and `before_id` from the oldest loaded message.
Each page is chronological. The stable timestamp/ID cursor works even when new
messages arrive or the boundary message is deleted. An empty page marks the end.
Pagination does not delete history or impose a total retention limit.

Newly uploaded files are stored separately instead of being embedded in every
polling response. Existing inline attachments remain readable for compatibility.

`SQLITE_DATABASE_PATH` chooses the database file; `CHAT_MEDIA_DIR` chooses the
upload directory. Compose persists both under `services/data/recommendation/`.
An existing persistent database is never replaced by the seed database on restart.
Reopening the frontend or recreating a container with this bind mount does not
reset conversations. Back up both the database and media directory together.
The PostgreSQL driver is not needed by this SQLite-backed service.
Follow the [first-upgrade backup steps](../../README.md#upgrading-shared-chat-without-losing-existing-data)
before replacing an old container, or its existing chat history can be lost.

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

# GlobeTrotter — Distributed Travel Assistant

A semester-long capstone project (CS 4122 — Distributed Systems) that evolves a single travel-recommendation app from a basic monolith into a production-grade, cloud-native, resilient distributed system, while being consumed by one cross-platform Flutter client the entire way through.

This README is the single source of truth for the whole project: what it is, why it's structured the way it is, how it's organized, and how each phase builds on the last.

---

## 1. What This Project Is

**GlobeTrotter Travel Assistant** lets users search travel destinations, get personalized recommendations, and create, manage, and share travel itineraries. It's built incrementally across four phases, each one intentionally introducing a new real-world distributed-systems problem, so the goal is to experience the limitations of each architecture firsthand rather than just read about them.

This is designed as a portfolio project. By the end, it should be something presentable to a potential employer as evidence of real distributed-systems experience, not just a class assignment.

### Business Requirements
Users can search for travel destinations and get personalized recommendations. Users can create, view, and manage travel itineraries, and share them with friends and family. The system must be able to handle millions of users globally. Recommendations are based on user preferences, past trips, and popular destinations. The system should be available 24/7 with minimal downtime.

### Technical Requirements
The system must be scalable to millions of users, resilient with no single point of failure, supportive of rapid iteration and deployment, cost-effective so it only pays for what's used, and observable through metrics, logging, and tracing.

---

## 2. Overall Architecture (Where We're Headed)

The Flutter client (one codebase covering web, mobile, and desktop) talks over REST with JWT authentication to a single API Gateway. The API Gateway routes requests to three backend services: the User Service, the Itinerary Service, and the Recommendation Service. Each of these owns its own database: a User DB, an Itinerary DB, and a Destinations DB respectively. On top of this, later phases add a Redis cache, message queues, circuit breakers, health checks, and distributed tracing, and the whole backend is deployed across multiple instances on Kubernetes with load balancing and auto-scaling.

The frontend never needs to know which phase the backend is in. It always talks to the same API Gateway endpoints. Only the base URL changes as the backend moves from localhost, to Docker, to Kubernetes, to a public cloud provider.

---

## 3. The Four Phases

Each phase has a deadline, a specific deliverable, and teaches a specific lesson by making you feel the pain that the next phase then solves.

**Phase 1 — The Monolith**, due end of Class 3, teaches the limitations of centralized architectures and how to build a working REST API. The deliverable is a working monolithic API with at least 5 endpoints, JSON file storage, and JWT authentication.

**Phase 2 — Microservices**, due end of Class 5, teaches service decomposition, inter-service communication, and API design. The deliverable is three independent services plus an API Gateway, each service with its own database.

**Phase 3 — Cloud Deployment**, due end of Class 8, teaches containerization, load balancing, auto-scaling, and cloud deployment. The deliverable is a cloud-deployed system with at least 3 instances per service, load balanced, with auto-scaling.

**Phase 4 — Resilience**, due end of Class 10, teaches caching, message queues, circuit breakers, and fault tolerance. The deliverable is a system that survives failures gracefully, with caching, queues, and circuit breakers all functioning.

### Phase 1 — The Monolith (current status: complete)

A single Flask application. All logic — API, business logic, and data access — lives in one deployable unit. Data is stored in plain JSON files on purpose, with no database yet, so the pain of concurrent access, no transactions, and no indexing is felt directly.

The endpoints are: `POST /register` to register a new user; `POST /login` to authenticate and receive a JWT; `GET /destinations` to search destinations publicly; `GET /recommendations` for personalized results, which requires a JWT; `POST /itineraries` to create an itinerary, which requires a JWT; and `GET /itineraries` to list the logged-in user's itineraries, which also requires a JWT.

The known limitations this phase demonstrates are vertical-only scaling, no failure isolation, full-app redeploys on every change, JSON file concurrency issues, codebase merge conflicts, and slow full-app testing.

### Phase 2 — Microservices (in progress)

The monolith is decomposed into three independent services, each with its own real database, communicating through an API Gateway that preserves the exact same external endpoint shapes.

The User Service owns users, registration, login, and JWT issuing. The Itinerary Service owns itineraries, their creation and listing. The Recommendation Service owns the destination catalogue and calls the User and Itinerary services over REST to build personalized recommendations. The API Gateway is the single entry point and routes requests to the correct service.

The new challenges introduced at this stage are network latency, cross-service data consistency, service discovery, distributed tracing, deployment orchestration, and integration testing complexity.

### Phase 3 — Cloud Deployment

Each service is containerized with Docker and deployed via Kubernetes or Docker Swarm to a public cloud provider such as AWS, GCP, or Azure, with load balancing across multiple instances of each service and auto-scaling based on CPU and memory usage.

The deliverable is at least 3 instances of each service, running behind a load balancer, auto-scaling, deployed to the cloud.

### Phase 4 — Resilience

Fault-tolerance features are layered on top of the cloud-deployed system so it survives real-world failures gracefully. This includes caching with Redis for frequently accessed data like destinations and recommendations; message queues such as RabbitMQ or SQS for asynchronous processing, for example generating recommendations as a background job; circuit breakers to stop calling a failing downstream service instead of cascading the failure; retries with exponential backoff for transient failures; health check endpoints that Kubernetes uses to restart unhealthy instances automatically; and distributed tracing through OpenTelemetry or Jaeger to trace a single request across multiple services.

The deliverable is a resilient system that survives failures, with caching, message queues, and circuit breakers all functioning.

---

## 4. The Frontend (Cross-Platform Client)

Alongside the backend phases, there's a single Flutter application, in the `frontend/` folder, that targets web, mobile on Android and iOS, and desktop on Windows, macOS, and Linux, all from one codebase. It's a thin client with no business logic of its own — it only calls the backend API and renders results.

The frontend was started right after Phase 1 was verified, since that's the point the API contract became stable. It should require little to no changes as the backend evolves through Phases 2 through 4, since the API Gateway from Phase 2 onward keeps the external endpoint shapes constant. Only the base URL changes as the backend moves environments.

The screens are Register, Login, Destinations with search and filtering, Recommendations, and Itineraries with creation and listing, along with navigation between screens and a logout action.

The frontend's responsibilities are to store the JWT securely using flutter_secure_storage, attach the Authorization Bearer token header automatically on protected calls, keep the API base URL in one config value rather than hardcoding it, and display backend errors as readable messages rather than raw stack traces.

---

## 5. Full Project Structure

The project root contains three main folders. The `backend/` folder holds the Phase 1 monolith, which is being migrated into the `services/` folder, and includes an `app/` folder, a `data/` folder, a `tests/` folder, a `requirements.txt`, a `Dockerfile`, and a `docker-compose.yml`.

The `services/` folder holds the Phase 2 microservices onward, containing a `user-service/`, an `itinerary-service/`, a `recommendation-service/`, an `api-gateway/`, and its own `docker-compose.yml`.

The `frontend/` folder holds the Flutter app covering web, mobile, and desktop, with a `lib/` folder, the standard platform folders such as `android/`, `ios/`, `web/`, `windows/`, `macos/`, and `linux/`, and a `pubspec.yaml`.

At the root sits this `README.md`.

---

## 6. Technology Stack

The backend, across all phases, is written in Python using Flask. The frontend, across all platforms, is written in Dart using Flutter. Phase 1 stores data in JSON files, while Phase 2 onward stores data in a real database per service, one instance or schema per service. Authentication uses JWT via PyJWT, with passwords hashed using Werkzeug. Containerization in Phase 3 uses Docker, orchestration uses Kubernetes or Docker Swarm, and the cloud provider is AWS, GCP, or Azure. Phase 4 introduces Redis for caching, RabbitMQ or SQS for messaging, Python circuit-breaking libraries such as pybreaker or circuitbreaker as equivalents to Java's Resilience4j or Hystrix, tenacity for retries, and OpenTelemetry or Jaeger for tracing. Testing throughout the backend uses pytest, and the whole project is version-controlled with Git.

One backend language is used throughout the entire project. Python was chosen at Phase 1 and is kept for every service in every later phase, so there's no need to introduce a second backend language. Only Bash for scripts and command-line usage, and YAML for Docker Compose and Kubernetes manifests, appear as supporting configuration and scripting alongside it.

---

## 7. Running the Project (Current State — Phase 1/2)

To run the backend, move into the `backend/` folder, install dependencies with `pip install -r requirements.txt`, and start the server with `python app/main.py`. The API becomes available at `http://localhost:5000`.

To run the backend's tests, from inside `backend/`, run `pytest tests/ -v`.

To run the frontend, move into the `frontend/` folder and run `flutter pub get` to install dependencies. Then run `flutter run -d chrome` for web, `flutter run` for a connected mobile device or emulator, or `flutter run -d windows`, `-d macos`, or `-d linux` for desktop.

To manually test the API without the frontend, use curl, Postman, or the VS Code REST Client extension to walk through the flow of registering, logging in, searching destinations, getting recommendations, creating an itinerary, and listing itineraries. See `backend/README.md` for exact example requests.

---

## 8. Project Status

Phase 1, the Monolith, is complete, tested, and verified. The Flutter frontend has been built against the Phase 1 API and runs cross-platform. Phase 2, Microservices with per-service databases, is currently in progress. Phase 3, Cloud Deployment, has not yet started. Phase 4, Resilience, has not yet started.

---

## 9. Key Principles to Remember Throughout

Each phase is incremental, so phases should not be skipped or combined. The frontend is independent of backend phase changes and should only ever need a base-URL update, never a rewrite. The database only enters at Phase 2, since Phase 1 is JSON-only on purpose. Each microservice owns its own data, and no service reaches into another service's database directly. Resilience in Phase 4 is treated as a requirement, not optional polish, since production systems must design for failure.

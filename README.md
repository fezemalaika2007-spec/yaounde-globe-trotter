# GlobeTrotter — Distributed Travel Assistant For Yaounde-Cameroon

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
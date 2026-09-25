# =========================================================
# Flutter Web Frontend - Nginx Production Container
# =========================================================

FROM nginx:1.25-alpine

LABEL name="globetrotter-frontend" \
    version="1.0.0" \
    description="GlobeTrotter Travel Assistant Frontend Client"

# Remove default Nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy the Flutter web build into Nginx
COPY build/web /usr/share/nginx/html

# Custom Nginx configuration for Flutter SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
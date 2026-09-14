# =========================================================
# Production Nginx Web Server for GlobeTrotter Frontend
# =========================================================
FROM nginx:1.25-alpine

LABEL name="globetrotter-frontend" \
      version="1.0.0" \
      description="GlobeTrotter Travel Assistant Frontend Client"

# Remove default Nginx welcome assets
RUN rm -rf /usr/share/nginx/html/*

# Copy compiled Flutter Web release bundle to Nginx root
COPY build/web /usr/share/nginx/html

# Copy custom Nginx configuration for Flutter SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose HTTP port 80
EXPOSE 80

# Run Nginx in foreground mode
CMD ["nginx", "-g", "daemon off;"]


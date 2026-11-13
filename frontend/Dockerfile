# Serve the Flutter web bundle built by run_docker.bat or the documented
# Flutter build command.
FROM nginx:1.25-alpine

LABEL name="globetrotter-frontend" \
    version="1.0.0" \
    description="GlobeTrotter Travel Assistant Frontend Client"

# Remove default Nginx website
RUN rm -rf /usr/share/nginx/html/*

COPY build/web /usr/share/nginx/html

# Custom Nginx configuration for Flutter SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
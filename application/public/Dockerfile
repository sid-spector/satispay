FROM nginx:latest

# Copy custom configuration file (optional)
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static website files (optional)
# COPY ./html /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
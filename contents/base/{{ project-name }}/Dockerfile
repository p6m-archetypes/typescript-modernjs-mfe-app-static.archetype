FROM node:22-alpine AS builder

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Set up workspace
WORKDIR /app

# Copy package files first for better caching
COPY package.json pnpm-lock.yaml* ./

# Install dependencies (with caching)
RUN pnpm fetch

# Copy application code
COPY . .

# Install with offline mode (using cache)
RUN pnpm install --frozen-lockfile --offline

# Clear any existing build artifacts and Modern.js cache
RUN rm -rf dist .modern-js node_modules/.modern-js

# Build the static assets
RUN pnpm run deploy

# Production stage - serve static files with nginx
FROM nginx:alpine

# Copy built static files to nginx html directory with proper ownership
COPY --from=builder --chown=nginx:nginx /app/.output/static/ /usr/share/nginx/html/static/

# Copy custom nginx configuration
COPY --from=builder --chown=nginx:nginx /app/nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
# Set hostname to 0.0.0.0 to make it accessible from outside the container
ENV HOSTNAME=0.0.0.0

# Expose the port the app runs on
ENV PORT={{ port }}
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
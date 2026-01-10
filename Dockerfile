# --------------------------------------------------------
# Stage 1: BUILD
# --------------------------------------------------------
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec first (for layer caching)
COPY pubspec.yaml ./
RUN dart pub get

# Copy source code
COPY . .

# Compile to native binary
RUN dart compile exe bin/dhook.dart -o dhook-server

# --------------------------------------------------------
# Stage 2: RUNTIME (Minimal)
# --------------------------------------------------------
FROM debian:stable-slim

# Install SSL certificates for HTTPS connections
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only the compiled binary from build stage
COPY --from=build /app/dhook-server /app/dhook-server

# Expose port
EXPOSE 3000

# Run the server
ENTRYPOINT ["./dhook-server", "server", "--port", "3000"]
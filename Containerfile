FROM debian:bookworm-slim

# Install runtime dependencies (adjust as needed)
RUN apt-get update && apt-get install -y \
    libstdc++6 libgcc-s1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy exported headless server binary + pack
# (these paths will be produced by the Godot export step)
COPY --chmod=755 build/server/tabletop_server.x86_64 /app/tabletop_server
COPY build/server/tabletop_server.pck /app/tabletop_server.pck

EXPOSE 8910/tcp

CMD ["/app/tabletop_server", "--main-pack", "tabletop_server.pck", "--server"]

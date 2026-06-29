# Use Python 3.11 slim base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PORT=8080

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install poetry

# Configure Poetry to not create virtual environments
RUN poetry config virtualenvs.create false

# Copy poetry files first for better caching
COPY pyproject.toml poetry.lock* ./

# Install dependencies (skip installing the project itself as a package)
RUN poetry install --no-root --only main

# Copy the application code
COPY . .

# Install the package in development mode if needed
RUN pip install -e .

# Expose the port that Cloud Run will use
EXPOSE $PORT

# Start command - Replace this with the correct entry point after inspection
# Based on typical MCP server patterns, try these in order:
CMD ["sh", "-c", \
    "# Try console script first \
    if command -v analytics-mcp >/dev/null 2>&1; then \
        echo 'Starting with console script...'; \
        exec analytics-mcp --host 0.0.0.0 --port $PORT; \
    # Try running as module \
    elif python -c 'import analytics_mcp.server' 2>/dev/null && python -c 'import sys; sys.exit(hasattr(__import__("analytics_mcp.server"), "main"))'; then \
        echo 'Starting as module...'; \
        exec python -m analytics_mcp.server --host 0.0.0.0 --port $PORT; \
    # Try FastAPI app with uvicorn \
    elif python -c 'from analytics_mcp.server import app' 2>/dev/null; then \
        echo 'Starting FastAPI app with uvicorn...'; \
        exec uvicorn analytics_mcp.server:app --host 0.0.0.0 --port $PORT; \
    # Try run_server function \
    elif python -c 'from analytics_mcp.server import run_server' 2>/dev/null; then \
        echo 'Starting with run_server function...'; \
        exec python -c 'from analytics_mcp.server import run_server; run_server(host=\"0.0.0.0\", port=int(os.environ.get(\"PORT\", 8080)))'; \
    else \
        echo 'ERROR: Could not determine how to start the server.'; \
        echo 'Available modules:'; \
        find . -name '*.py' -path './analytics_mcp/*' | head -10; \
        echo 'Please update the CMD in Dockerfile with the correct entry point.'; \
        exit 1; \
    fi"]
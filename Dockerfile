# syntax=docker/dockerfile:1.4

# ---------------------------------------------------------------------------
# Build-time stage – compile/install Python dependencies
# ---------------------------------------------------------------------------
ARG CUDA_VERSION=12.4.1
ARG UBUNTU_VERSION=22.04
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# Reduce apt-get noise and add retry logic
RUN echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::http::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries && \
    echo 'Acquire::ftp::Timeout "30";' >> /etc/apt/apt.conf.d/80-retries

# Install only the packages needed to build Python wheels
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv python3-dev \
        git curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip to a version that works on Ubuntu 22.04
RUN python3 -m pip install --upgrade pip

WORKDIR /src
COPY requirements.txt .
# Install dependencies into the builder image (cached layer)
RUN pip3 install --no-cache-dir -r requirements.txt

# ---------------------------------------------------------------------------
# Runtime stage – minimal image that runs the app
# ---------------------------------------------------------------------------
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app:$PYTHONPATH

# Install only runtime system packages (no compilers, no pip install at run-time)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip git \
        libreoffice default-jre poppler-utils \
        libgl1 libglib2.0-0 libgomp1 \
        fonts-dejavu fonts-dejavu-core fonts-dejavu-extra && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install them
COPY requirements.txt .
RUN python3 -m pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create required directories and a placeholder log file
RUN mkdir -p /data /var/log && touch /var/log/app.log

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 7860

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "demo/app.py"]

FROM ubuntu:24.04

# Configure apt to avoid unnecessary packages
RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker

# Create application user
RUN useradd -ms /bin/bash apprunner

# Switch to root for package installation
USER root

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    clang-18 \
    llvm-18-dev \
    llvm-18-tools \
    git \
    make \
    gcc \
    g++ \
    libstdc++-14-dev

# Switch back to apprunner
USER apprunner
WORKDIR /home/apprunner

# Clone Odin compiler
RUN git clone https://github.com/odin-lang/Odin

# Set working directory
WORKDIR /home/apprunner/Odin

# Set build environment variables
ENV CC=clang-18 \
    CXX=clang++-18 \
    LLVM_CONFIG=/usr/bin/llvm-config-18

# Build with optimizations
RUN make release-native

# Add Odin to PATH
ENV PATH="/home/apprunner/Odin:${PATH}"

# Set working directory
WORKDIR /home/apprunner

# Clone Locke
RUN git clone https://github.com/navarrastar/Locke

# Set working directory
WORKDIR /home/apprunner/Locke

# Odin run server command
CMD ["odin", "run", "src/", "-define:SERVER=true", "-o:speed"]
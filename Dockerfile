# ----------------------------
# ---- DTN7 builder stage ----
FROM rust:1-bookworm AS dtn7-builder
ARG DTN7_REF=master

RUN apt-get update && apt-get install -y --no-install-recommends \
    git pkg-config libssl-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch ${DTN7_REF} https://github.com/dtn7/dtn7-rs.git

WORKDIR /src/dtn7-rs
RUN cargo build --release --locked


# -------------------------------
# ---- Core/EMANE builder stage --
FROM ubuntu:22.04 AS core-builder
ARG VERSION=release-9.2.1
ARG STAGE=/opt/stage

ENV DEBIAN_FRONTEND=noninteractive

# Build-time deps (toolchain + *-dev)
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  wget \
  curl \
  unzip \
  tzdata \
  gawk \
  sudo \
  build-essential \
  gcc \
  pkg-config \
  automake \
  libtool \
  uuid-dev \
  protobuf-compiler \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  python3-tk \
  tk \
  libev-dev \
  libreadline-dev \
  libpcap-dev \
  libpcre3-dev \
  libxml2-dev \
  libprotobuf-dev \
  libyaml-dev

# --- CORE ---
WORKDIR /opt/core
ENV PATH="/root/.local/bin:${PATH}"
RUN git clone --branch ${VERSION} --depth 1 https://github.com/coreemu/core.git /opt/core && \
    ./setup.sh && \
    inv install

RUN mkdir -p ${STAGE}/usr/local && \
    cp -a /usr/local/* ${STAGE}/usr/local/

RUN mkdir -p ${STAGE}/opt && \
    cp -a /opt/core ${STAGE}/opt/core

# --- EMANE (build + install to staged root via DESTDIR) ---
WORKDIR /opt
RUN git clone https://github.com/adjacentlink/emane.git /opt/emane && \
    cd /opt/emane && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j"$(nproc)" && \
    make DESTDIR="${STAGE}" install

# --- EMANE python bindings (needs protoc; do it in builder only) ---
RUN ARCH1=$(uname -m | sed -e s/arm64/aarch_64/ | sed -e s/aarch64/aarch_64/) && \
    wget -q https://github.com/protocolbuffers/protobuf/releases/download/v3.19.6/protoc-3.19.6-linux-$ARCH1.zip && \
    mkdir -p /opt/protoc && \
    unzip -q protoc-3.19.6-linux-$ARCH1.zip -d /opt/protoc && \
    PATH=/opt/protoc/bin:$PATH && \
    cd /opt/emane/src/python && \
    make clean && \
    make && \
    /opt/core/venv/bin/python -m pip install .

# --- core-helpers -> stage into /usr/local/bin ---
WORKDIR /root
RUN git clone --depth 1 https://github.com/gh0st42/core-helpers && \
    mkdir -p ${STAGE}/usr/local/bin && \
    cp core-helpers/bin/* ${STAGE}/usr/local/bin/ && \
    rm -rf core-helpers


# ----------------------------
# ---- Runtime stage ----------
FROM ubuntu:22.04 AS runtime
ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps only (no compiler, no *-dev)
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  tzdata \
  python3 \
  python3-venv \
  python3-tk \
  tk \
  iputils-ping \
  net-tools \
  iproute2 \
  nftables \
  ethtool \
  tcpdump \
  curl \
  mtr \
  tmux \
  iperf \
  gawk \
  xterm \
  libssl3 \
  libev4 \
  libreadline8 \
  libpcap0.8 \
  libpcre3 \
  libxml2 \
  libyaml-0-2 \
  libprotobuf23 \
  x11-xserver-utils \
 && rm -rf /var/lib/apt/lists/*

# Bring staged EMANE + helpers (/usr, /etc, /usr/local, etc.)
COPY --from=core-builder /opt/stage/ /

# Bring CORE tree (venv + configs etc.)
COPY --from=core-builder /opt/core /opt/core
ENV PATH="$PATH:/opt/core/venv/bin"

# Copy DTN7 binaries from builder (single COPY + install)
COPY --from=dtn7-builder /src/dtn7-rs/target/release/dtnd \
                         /src/dtn7-rs/target/release/dtnquery \
                         /src/dtn7-rs/target/release/dtnsend \
                         /src/dtn7-rs/target/release/dtnrecv \
                         /src/dtn7-rs/target/release/dtntrigger \
                         /tmp/dtn7-bin/
RUN install -m 0755 /tmp/dtn7-bin/* /usr/local/bin/ && rm -rf /tmp/dtn7-bin

COPY resources/.Xresources /root/.Xresources
COPY resources/update-custom-services.sh /update-custom-services.sh
COPY resources/entrypoint.sh /root/entrypoint.sh

# Optional: make gRPC listen on all interfaces
RUN sed -i 's/^grpcaddress *= *.*/grpcaddress = 0.0.0.0/g' /opt/core/etc/core.conf || true

EXPOSE 50051
VOLUME /shared
ENTRYPOINT ["/root/entrypoint.sh"]

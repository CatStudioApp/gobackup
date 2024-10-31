# PostgreSQL builder stage
FROM alpine:latest as pg_builder
ARG PG_VERSION=17.0
RUN apk add --no-cache \
  gcc \
  g++ \
  make \
  readline-dev \
  zlib-dev \
  icu-dev \
  icu-libs \
  pkgconfig \
  wget \
  bison \
  flex \
  perl

WORKDIR /tmp
RUN wget https://ftp.postgresql.org/pub/source/v${PG_VERSION}/postgresql-${PG_VERSION}.tar.gz && \
  tar xf postgresql-${PG_VERSION}.tar.gz && \
  cd postgresql-${PG_VERSION} && \
  ./configure --without-server --without-readline --without-icu && \
  make -C src/bin/pg_dump && \
  make -C src/bin/psql

# Main builder stage
FROM alpine:latest as builder
ARG VERSION=latest
RUN apk add --no-cache \
  curl \
  ca-certificates \
  openssl \
  sqlite \
  tar \
  gzip \
  pigz \
  bzip2 \
  coreutils \
  lzip \
  xz-dev \
  lzop \
  xz \
  zstd \
  libstdc++ \
  gcompat \
  icu \
  tzdata \
  && \
  rm -rf /var/cache/apk/*

# Copy PostgreSQL binaries from pg_builder
COPY --from=pg_builder /tmp/postgresql-${PG_VERSION}/src/bin/pg_dump/pg_dump /usr/local/bin/
COPY --from=pg_builder /tmp/postgresql-${PG_VERSION}/src/bin/pg_dump/pg_dumpall /usr/local/bin/
COPY --from=pg_builder /tmp/postgresql-${PG_VERSION}/src/bin/psql/psql /usr/local/bin/

# Rest of your existing setup
WORKDIR /tmp
RUN wget https://aka.ms/sqlpackage-linux && \
  unzip sqlpackage-linux -d /opt/sqlpackage && \
  rm sqlpackage-linux && \
  chmod +x /opt/sqlpackage/sqlpackage

ENV PATH="${PATH}:/opt/sqlpackage"

# Install the influx CLI
ARG INFLUX_CLI_VERSION=2.7.5
RUN case "$(uname -m)" in \
  x86_64) arch=amd64 ;; \
  aarch64) arch=arm64 ;; \
  *) echo 'Unsupported architecture' && exit 1 ;; \
  esac && \
  curl -fLO "https://dl.influxdata.com/influxdb/releases/influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz" \
  -fLO "https://dl.influxdata.com/influxdb/releases/influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz.asc" && \
  tar xzf "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz" && \
  cp influx /usr/local/bin/influx && \
  rm -rf "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}" \
  "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz" \
  "influxdb2-client-${INFLUX_CLI_VERSION}-linux-${arch}.tar.gz.asc" \
  "influx" && \
  influx version

# Install the etcdctl
ARG ETCD_VER="v3.5.11"
RUN case "$(uname -m)" in \
  x86_64) arch=amd64 ;; \
  aarch64) arch=arm64 ;; \
  *) echo 'Unsupported architecture' && exit 1 ;; \
  esac && \
  curl -fLO https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${arch}.tar.gz && \
  tar xzf "etcd-${ETCD_VER}-linux-${arch}.tar.gz" && \
  cp etcd-${ETCD_VER}-linux-${arch}/etcdctl /usr/local/bin/etcdctl && \
  rm -rf "etcd-${ETCD_VER}-linux-${arch}/etcdctl" \
  "etcd-${ETCD_VER}-linux-${arch}.tar.gz" && \
  etcdctl version

ADD install /install
RUN /install ${VERSION} && rm /install

CMD ["/usr/local/bin/gobackup", "run"]


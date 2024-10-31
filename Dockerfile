
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

RUN ls -l /usr/local/bin/gobackup
CMD ["/usr/local/bin/gobackup", "run"]


FROM postgres:17-alpine as prod

# Install OpenSSL in the production image
RUN apk add --no-cache openssl

COPY --from=builder /usr/local/bin/gobackup /usr/local/bin/gobackup
RUN ls -l /usr/local/bin/gobackup

RUN mkdir -p /root/.gobackup/

CMD ["/usr/local/bin/gobackup", "run"]

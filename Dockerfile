FROM debian:12.11 AS build

ARG UNBOUND_VERSION=1.23.1

WORKDIR /usr/src

# Install unbound
RUN <<EOL
apt-get update  --quiet --yes
apt-get install --quiet --yes --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  libexpat-dev \
  libsodium-dev \
  libssl-dev

# Download unbound
curl \
  --output unbound-${UNBOUND_VERSION}.tar.gz \
  https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz

# Extract unbound
tar \
  --extract \
  --file=unbound-${UNBOUND_VERSION}.tar.gz \
  --gunzip

# Build unbound
cd /usr/src/unbound-${UNBOUND_VERSION}
./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --disable-systemd \
  --enable-static \
  --enable-static-exe
make
make install
make install DESTDIR=/tmp/install-unbound
EOL

FROM debian:12.11

COPY --from=build /tmp/install-unbound/etc/unbound /etc/unbound
COPY --from=build /tmp/install-unbound/usr/include /usr/include
COPY --from=build /tmp/install-unbound/usr/lib     /usr/lib
COPY --from=build /tmp/install-unbound/usr/sbin    /usr/sbin
COPY --from=build /tmp/install-unbound/usr/share   /usr/share

# Install netcat
RUN <<EOL
apt-get update  --quiet --yes
apt-get upgrade --quiet --yes
apt-get install --quiet --yes --no-install-recommends \
  ca-certificates \
  curl \
  netcat-openbsd
EOL

# Download root name servers cache
RUN <<EOL
cp /etc/unbound/unbound.conf /etc/unbound/unbound.default.conf
curl \
  --output /etc/unbound/named.cache \
  https://www.internic.net/domain/named.cache
EOL

# Create unbound user
RUN <<EOL
groupadd \
  --gid 1000 \
  unbound
useradd \
  --home-dir /var/lib/unbound \
  --gid 1000 \
  --create-home \
  --shell /usr/sbin/nologin \
  --uid 1000 \
  unbound
EOL

WORKDIR /

# Copy configuration
COPY unbound.conf /etc/unbound/unbound.conf

ENTRYPOINT [ "/usr/sbin/unbound" ]

CMD [ "-c", "/etc/unbound/unbound.conf", "-d", "-v" ]

HEALTHCHECK CMD nc -4 -u -z 127.0.0.1 53 || exit 1
# EOF

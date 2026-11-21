# syntax=docker/dockerfile:1

ARG BISQ_VERSION=1.10.12
ARG BASEIMAGE=jlesage/baseimage-gui:debian-13-v4.14.0

# Stage 1: download the Bisq package and verify its signature.
FROM debian:13-slim AS fetch
ARG BISQ_VERSION
# Full primary-key fingerprints of the Bisq release signers accepted by this build.
# The signer's public key is downloaded with the release; trust comes only from this list.
ARG BISQ_SIGNER_FPRS="B493319106CC3D1F252E19CBF806F422E222AA02 B8A5D214ADFAA387A14C8BCF02AA2BAE387C8307"

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /fetch
RUN set -eu; \
    base="https://github.com/bisq-network/bisq/releases/download/v${BISQ_VERSION}"; \
    deb="Bisq-64bit-${BISQ_VERSION}.deb"; \
    curl -fsSL -o bisq.deb "${base}/${deb}"; \
    curl -fsSL -o bisq.deb.asc "${base}/${deb}.asc"; \
    keyid="$(curl -fsSL "${base}/signingkey.asc" | tr -d '[:space:]')"; \
    case "${keyid}" in ''|*[!0-9A-F]*) echo "Invalid signingkey.asc: '${keyid}'" >&2; exit 1 ;; esac; \
    curl -fsSL -o signer.asc "${base}/${keyid}.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --quiet --import signer.asc; \
    gpg --batch --status-fd 1 --verify bisq.deb.asc bisq.deb > gpg-status; \
    fpr="$(awk '$2 == "VALIDSIG" { print $NF }' gpg-status)"; \
    [ -n "${fpr}" ] || { echo "No valid signature" >&2; exit 1; }; \
    case " ${BISQ_SIGNER_FPRS} " in \
        *" ${fpr} "*) echo "Signed by trusted key ${fpr}" ;; \
        *) echo "Signed by untrusted key '${fpr}'" >&2; exit 1 ;; \
    esac

# Stage 2: the application image.
FROM ${BASEIMAGE}
ARG BISQ_VERSION

# add-pkg is the base image's installer: package scripts need /config/log (the target of
# /var/log) and a user database during the build; add-pkg provides both and cleans up after.
# Packages that do not depend on the Bisq version come first, so that a new Bisq version
# rebuilds only the layer of Bisq.
# JavaFX extracts its own native libraries at runtime and needs GTK 3, which the Bisq package
# does not declare. GTK 3 needs a D-Bus session bus; dbus-x11 provides it, otherwise apt picks
# dbus-user-session, which pulls in systemd. wmctrl is used by the service bisq-maximize.
RUN add-pkg \
        libgtk-3-0t64 \
        dbus-x11 \
        wmctrl

# The package bundles its own Java runtime; apt resolves only the native libraries it declares.
# A bind mount keeps the 400 MB package out of the image layers.
# The package's postinst registers a menu entry with xdg-desktop-menu, which fails unless
# the XDG menu directories exist.
RUN --mount=type=bind,from=fetch,source=/fetch/bisq.deb,target=/tmp/bisq.deb \
    mkdir -p /etc/xdg/menus /usr/share/applications /usr/share/desktop-directories \
 && add-pkg /tmp/bisq.deb

RUN install_app_icon.sh "https://raw.githubusercontent.com/bisq-network/bisq/v${BISQ_VERSION}/desktop/package/macosx/Bisq.iconset/icon_512x512.png"

COPY --chmod=0755 startapp.sh /startapp.sh
# etc/openbox/main-window-selection.xml limits the base image's rule (maximized, no decorations)
# to the main window: the dialogs of Bisq are windows of the same class with an empty title.
COPY rootfs/ /
RUN chmod 0755 /etc/services.d/bisq-maximize/run

# 80 % of this size is the minimum size of the Bisq window (1020x619). The web interface resizes
# the screen to the browser window by default, and scales the picture instead only when the
# browser window is smaller than 80 % of this size.
ENV DISPLAY_WIDTH=1275 \
    DISPLAY_HEIGHT=774

# SERVICES_GRACETIME: time for Bisq to close the wallet and Tor after SIGTERM, before SIGKILL.
RUN set-cont-env APP_NAME "Bisq" \
 && set-cont-env APP_VERSION "${BISQ_VERSION}" \
 && set-cont-env SERVICES_GRACETIME 30000

LABEL org.opencontainers.image.title="BisqFTS" \
      org.opencontainers.image.description="Bisq desktop application, accessible from a web browser or a VNC client" \
      org.opencontainers.image.version="${BISQ_VERSION}" \
      org.opencontainers.image.url="https://bisq.network" \
      org.opencontainers.image.source="https://github.com/jaclas/bisqfts"

VOLUME ["/config"]
EXPOSE 5800 5900

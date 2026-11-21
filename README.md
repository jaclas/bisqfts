# BisqFTS

A Docker image of [Bisq](https://bisq.network), the decentralized bitcoin exchange, used from a
web browser or a VNC client. Base image: `jlesage/baseimage-gui` (Debian 13).

## Image

```
ghcr.io/jaclas/bisqfts:latest
ghcr.io/jaclas/bisqfts:<Bisq version>
```

GitHub Actions builds the image from this repository (`.github/workflows/build.yml`) for
`linux/amd64`, the only architecture Bisq publishes a Linux package for:

- on every change to the files of the image, for the latest Bisq release;
- once a day, when Bisq has a release that is not in the registry yet;
- on manual dispatch, for any Bisq version.

The tag `latest` moves only with the latest Bisq release. Every build installs the current
Debian packages; there is no build cache.

The build downloads the `.deb` package from the Bisq release on GitHub and verifies its
signature. It accepts only a signature made by a key whose full fingerprint is listed in
`BISQ_SIGNER_FPRS` in the `Dockerfile`. A signature by any other key stops the build: a new Bisq
signing key is added to the list only after its fingerprint has been checked.

## Run

```
docker run -d --name bisqfts -p 5800:5800 -p 5900:5900 -e USER_ID=99 -e GROUP_ID=100 -e UMASK=0077 -e VNC_PASSWORD=secret --memory=8g --stop-timeout=60 -v /path/to/data:/config ghcr.io/jaclas/bisqfts:latest
```

GUI: `http://<host>:5800` in a web browser, or `<host>:5900` in a VNC client.

| Parameter | Meaning |
|---|---|
| `USER_ID`, `GROUP_ID` | owner of the files in `/config`; on Unraid `99` (`nobody`) and `100` (`users`) |
| `UMASK` | `0077`: new files 600, directories 700, so only the owner can read the wallet |
| `VNC_PASSWORD` | password of the GUI (web browser and VNC); always set it, see "Tor" |
| `--memory` | memory limit; Bisq takes 50 % of the limit for the Java heap, without a limit half of the host's memory |
| `--stop-timeout` | at least 30 s: the time Bisq gets to close the wallet and Tor |
| `JAVA_TOOL_OPTIONS` | additional Java options, e.g. `-Xmx3g`; they take precedence over the options of the image |

## Data

| Directory | Contents |
|---|---|
| `/config/bisq` | everything that belongs to Bisq: wallet, DAO state, `bisq.properties`, logs (`--appDataDir`) |
| `/config/xdg`, `/config/log`, `/config/var` | settings of the GUI and of the image's services; they are recreated |

A backup of the Bisq account is a copy of `/config/bisq` made while the container is stopped.
Make one before an update to a new Bisq version.

## Display

The web interface resizes the container's screen to the browser window (in the left panel
**Scaling mode → Remote Resizing**), and the service `bisq-maximize` keeps the Bisq window
maximized, so it follows the size of the browser. When the browser window is smaller than the
minimum Bisq window (1020×619), the web interface scales the picture by default. The browser
remembers the choice made in the panel.

## Tor

Bisq runs Tor in its sandbox `sandy`. In a container with Docker's default settings the sandbox
runs at the level `host-network` (kernel 6.12 or newer) or `host-network-signals` (older
kernels): Tor cannot read the wallet's files, but it can connect to services in the container's
network, including this container's VNC, and in the local network. That is why `VNC_PASSWORD` is
always needed. The highest level, with a network of Tor's own, needs the container to be allowed
to create user namespaces; this image does not enable that.

The sandbox needs the Landlock module in the host's kernel. A kernel without it (e.g. Unraid
7.3.3, built without `CONFIG_SECURITY`) cannot give the sandbox at any level: Bisq then does not
start Tor (`SandboxUnavailableException` in `/config/bisq/bisq.log`) and offers the button
**Turn off the sandbox and shut down**. The button adds `useTorSandbox=false` to
`/config/bisq/bisq.properties` and closes Bisq; after the container is started again, Tor runs
without the sandbox, as in Bisq up to 1.10.10, with access to all files of the container,
including the wallet. When the host gets Landlock, remove that line while the container is
stopped.

## Unraid

1. Template `unraid/my-BisqFTS.xml` to `/boot/config/plugins/dockerMan/templates-user/`,
   then **Docker → Add Container → BisqFTS → Apply**. Unraid pulls the image from `ghcr.io`.
2. A new image under `latest` shows up on the Docker page as an available update; the update
   button pulls it and recreates the container. Back up `/config/bisq` first when the Bisq
   version changes.

## Build locally

```
docker build -t bisqfts:1.10.12 .
```

Another Bisq version: `docker build --build-arg BISQ_VERSION=1.10.13 -t bisqfts:1.10.13 .`

## License

The files of this repository are under the MIT license (`LICENSE`). Bisq, which the image
installs, is under the GNU AGPL-3.0; the base image `jlesage/baseimage-gui` is under the MIT
license.

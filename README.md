# coreemu-dtn

`coreemu-dtn` is a Docker image that bundles **CORE Emulator 9** with
a **Delay-Tolerant Networking (DTN)** stack based on **dtn7** (Rust
implementation).

The goal is to provide a ready-to-use environment for experimenting with DTN
protocols and behaviors inside reproducible CORE network scenarios, without
having to manually build or integrate DTN software into CORE.

The image is primarily intended for **research, experimentation, and prototyping
of DTN-based networks**, especially in challenged or intermittently connected
environments.

Tested on **Linux (Ubuntu)**.

## What is included

* CORE Emulator **v9.2.1**
* EMANE
* DTN implementation: [dtn7-rs](https://github.com/dtn7/dtn7-rs)
* Custom CORE service to start `dtnd` inside nodes
* Example scenario with DTN-enabled nodes

Current image size: **~1.05 GB**

## Example scenario

An example CORE scenario is provided at:

```
/shared/scenarios/test.xml
```

It contains:

* 3 nodes
* A shared wireless network
* DTN daemon (`dtnd`) available as a CORE service

This allows you to immediately start CORE, load the scenario, and experiment
with DTN communication between nodes.

## Build the image

A Makefile is provided.

```bash
make build
```

This builds the image and tags it as:

* `ghcr.io/slintak/coreemu-dtn:latest`
* `ghcr.io/slintak/coreemu-dtn:release-9.2.1`

To run Coreemu:

```bash
make run
```

This uses `run.sh` to start the container with the required privileges,
networking, and X11 forwarding for CORE GUI.

CORE GUI will start automatically.

## DTN CORE service

The image includes a **custom CORE service** that can be attached to nodes to
automatically start the DTN daemon.

### DTND service definition

```python
from core.services.base import CoreService


class DtndService(CoreService):
    name: str = "DTND"
    group: str = "DTN"

    directories = []
    files = []
    executables = ["dtnd"]
    dependencies = []

    startup = [
        "dtnd -C udp -r epidemic -e incoming -i 10s -j 30s "
        "> /var/log/dtnd.log 2>&1 &"
    ]
    shutdown = [
        "killall dtnd || true",
    ]
```

When attached to a node, this service:

* Starts `dtnd` inside the node namespace
* Enables UDP convergence layer
* Uses epidemic routing
* Logs output to `/var/log/dtnd.log`

## DTN quick cheatsheet

All commands below are executed **inside CORE node terminals**.

### Check dtnd status

```bash
tail -f /var/log/dtnd.log
```

### Send a bundle (hello world)

```bash
echo "hello world" | dtnsend --receiver dtn://n21/incoming
```

### Receive bundles

```bash
dtnrecv
```

### Query node information

```bash
dtnquery info
```

### List known peers

```bash
dtnquery peers
```

## Notes and limitations

* Requires **Linux** (tested on Ubuntu)
* Requires Docker with:
  * `--privileged`
  * `--network host`
  * NET_ADMIN / SYS_ADMIN capabilities
* Designed for experimentation, not production use

## Inspiration and credits

This project was inspired by: [gh0st42/coreemu-docker](https://github.com/gh0st42/coreemu-docker)

This repository is a clean reimplementation from scratch, focused specifically
on **DTN experimentation and research**.

## License

MIT License

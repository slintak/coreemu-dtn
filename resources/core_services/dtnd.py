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

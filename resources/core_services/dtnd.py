from core.services.base import CoreService


class DtndService(CoreService):
    name: str = "DTND"
    group: str = "DTN"

    directories = []
    files = []
    executables = ["dtnd"]
    dependencies = []

    startup = [
        "/shared/myservices/dtnd-start.sh start",
    ]

    shutdown = [
        "/shared/myservices/dtnd-start.sh stop",
    ]

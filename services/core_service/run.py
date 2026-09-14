"""Frozen entrypoint: `core_service.exe` serves the localhost API on 127.0.0.1 only."""
import multiprocessing
import os

import uvicorn

from app.main import app

if __name__ == "__main__":
    multiprocessing.freeze_support()
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=int(os.environ.get("COREPHOTO_PORT", "42839")),
        log_level="warning",
    )

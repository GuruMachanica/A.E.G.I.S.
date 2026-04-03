from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import CORS_ALLOW_ORIGINS
from .db import init_db
from .routers.assist_router import router as assist_router
from .routers.auth_router import router as auth_router
from .routers.data_router import router as data_router
from .routers.legacy_ws_router import router as legacy_ws_router
from .routers.system_router import router as system_router


def create_app() -> FastAPI:
    app = FastAPI(title="A.E.G.I.S Backend")
    init_db()

    origins = [o.strip() for o in CORS_ALLOW_ORIGINS.split(",") if o.strip()]
    allow_all_origins = origins == ["*"]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if allow_all_origins else origins,
        allow_methods=["*"],
        allow_headers=["*"],
        allow_credentials=not allow_all_origins,
    )

    app.include_router(auth_router)
    app.include_router(assist_router)
    app.include_router(legacy_ws_router)
    app.include_router(data_router)
    app.include_router(system_router)
    return app

"""
FastAPI Application Factory for A.E.G.I.S Security
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.config import CORS_ALLOW_ORIGINS
from .core.db import init_db
from .api.auth import router as auth_router
from .api.calls import router as calls_router
from .api.records import router as records_router
from .api.reports import router as reports_router
from .api.health import router as health_router
from .api.legacy_ws import router as legacy_ws_router

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Initializing A.E.G.I.S Backend application and database...")
    init_db()
    yield
    # Shutdown
    logger.info("A.E.G.I.S Backend application shutdown complete.")


def create_app() -> FastAPI:
    app = FastAPI(
        title="A.E.G.I.S Security Platform",
        description="Real-time Deepfake Voice Defense & NLP Scam Threat Intelligence API",
        version="2.0.0",
        lifespan=lifespan,
    )

    origins = [o.strip() for o in CORS_ALLOW_ORIGINS.split(",") if o.strip()]
    allow_all = origins == ["*"]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if allow_all else origins,
        allow_methods=["*"],
        allow_headers=["*"],
        allow_credentials=not allow_all,
    )

    # Register Routers
    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(calls_router)
    app.include_router(records_router)
    app.include_router(reports_router)
    app.include_router(legacy_ws_router)

    return app

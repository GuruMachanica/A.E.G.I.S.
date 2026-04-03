from fastapi import APIRouter, Response

from ..ml.runtime import scoring_service


router = APIRouter()


@router.get("/")
def root() -> dict[str, str]:
    return {
        "service": "A.E.G.I.S Backend",
        "status": "ok",
        "health": "/health",
    }


@router.get("/favicon.ico")
def favicon() -> Response:
    return Response(status_code=204)


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/models/status")
def models_status() -> dict[str, object]:
    return scoring_service.status()

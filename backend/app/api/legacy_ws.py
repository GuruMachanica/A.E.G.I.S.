"""
Legacy WebSocket compatibility router
"""
from fastapi import APIRouter, WebSocket
from .calls import live_audio_websocket

router = APIRouter(tags=["legacy"])


@router.websocket("/ws")
async def legacy_ws_endpoint(websocket: WebSocket) -> None:
    await live_audio_websocket(websocket)

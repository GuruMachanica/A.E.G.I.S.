from fastapi import APIRouter, WebSocket

from .assist_router import _handle_live_audio


router = APIRouter(tags=["legacy-compat"])


@router.websocket("/ws/live-audio")
async def legacy_ws_live_audio(ws: WebSocket) -> None:
    await _handle_live_audio(ws)


@router.websocket("/ws/call-monitor")
async def legacy_ws_call_monitor(ws: WebSocket) -> None:
    await _handle_live_audio(ws)

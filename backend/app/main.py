"""FastAPI app: a thin streaming proxy in front of the model provider.

The Flutter client POSTs its system prompt + history here and receives the raw
A2UI text deltas as NDJSON (one JSON object per line). NDJSON is used instead of
plain text so arbitrary content — including newlines inside the A2UI JSON — is
preserved exactly:

    {"delta": "..."}      # zero or more, in order
    {"done": true}        # terminal success marker
    {"error": "..."}      # terminal error marker (mid-stream failures)
"""

import asyncio
import contextlib
import json
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any

import httpx
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse

from .config import settings
from .deepgram_agent import DeepgramAgentSession
from .featherless import stream_deltas
from .schemas import ChatRequest, Message
from .voice_prompt import CALL_EMERGENCY_FUNCTION_NAME, RENDER_FUNCTION_NAME

logger = logging.getLogger("sos.voice")

HTTP_TIMEOUT = httpx.Timeout(connect=10.0, read=300.0, write=10.0, pool=10.0)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.http_client = httpx.AsyncClient(timeout=HTTP_TIMEOUT)
    yield
    await app.state.http_client.aclose()


app = FastAPI(
    title="SOS Emergency — GenUI Backend",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list(),
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict:
    """Liveness check; also reports whether provider API keys are configured."""
    return {
        "status": "ok",
        "model_key_configured": bool(settings.render_api_key),
        "voice_key_configured": bool(settings.deepgram_api_key),
    }


def _ndjson(obj: dict) -> str:
    return json.dumps(obj, separators=(",", ":")) + "\n"


def _upstream_error_response(error: httpx.HTTPStatusError) -> JSONResponse:
    status = error.response.status_code if error.response is not None else 502
    if status >= 500:
        status = 502
    return JSONResponse(
        status_code=status,
        content={"error": f"Upstream error: {error}"},
    )


@app.post("/v1/chat/stream")
async def chat_stream(req: ChatRequest, request: Request):
    logger.info(
        "compose request: catalog=%s model=%s turns=%d",
        req.catalog_version,
        req.model,
        len(req.messages),
    )
    if not settings.render_api_key:
        return JSONResponse(
            status_code=503,
            content={
                "error": (
                    f"No API key configured for render_provider="
                    f"'{settings.render_provider}'."
                )
            },
        )

    client = request.app.state.http_client
    deltas = stream_deltas(req, client)

    # Pull the first chunk before returning StreamingResponse so immediate
    # upstream failures (401, 400, etc.) surface as proper HTTP error codes.
    try:
        first_delta = await anext(deltas)
    except StopAsyncIteration:
        first_delta = None
    except httpx.HTTPStatusError as error:
        return _upstream_error_response(error)
    except httpx.HTTPError as error:
        return JSONResponse(
            status_code=502,
            content={"error": f"Request failed: {error}"},
        )

    async def body() -> AsyncIterator[str]:
        if first_delta is not None:
            yield _ndjson({"delta": first_delta})
        try:
            async for delta in deltas:
                yield _ndjson({"delta": delta})
            yield _ndjson({"done": True})
        except httpx.HTTPError as error:
            yield _ndjson({"error": f"Request failed: {error}"})

    return StreamingResponse(
        body(),
        media_type="application/x-ndjson",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# --------------------------------------------------------------------------- #
# Voice agent (Deepgram) — the hands-free layer.
#
# Flutter holds ONE websocket to /v1/voice/agent. The backend holds a second
# websocket to Deepgram's Voice Agent. We relay audio both ways and, when the
# managed think model calls render_emergency_ui, we run the EXISTING A2UI
# pipeline (featherless.stream_deltas) and push the resulting deltas back down
# the same Flutter socket — never reading the UI JSON aloud.
#
# Frame contract to Flutter (binary = TTS audio; text = NDJSON control/data):
#   {"render_start": {...}}      a render is beginning; arguments echoed
#   {"delta": "..."}             one A2UI text chunk (same as /v1/chat/stream)
#   {"done": true}               the current render's A2UI stream finished
#   {"transcript": {"role","content"}}   a spoken turn (user or assistant)
#   {"event": "AgentThinking"}   lightweight status passthrough
#   {"action": "call_emergency"} user asked to call 911 — dial on device
#   {"error": "..."}             a terminal/recoverable error
# --------------------------------------------------------------------------- #


@app.get("/v1/voice/health")
async def voice_health() -> dict:
    """Reports whether both keys the voice agent needs are configured."""
    return {
        "status": "ok",
        "deepgram_key_configured": bool(settings.deepgram_api_key),
        "featherless_key_configured": bool(settings.render_api_key),
    }


# Status events worth forwarding to the client for UI affordances (e.g. show a
# "thinking" indicator). The rest (Welcome, SettingsApplied, ...) are ignored.
_FORWARDED_EVENTS = {
    "UserStartedSpeaking",
    "AgentThinking",
    "AgentStartedSpeaking",
    "AgentAudioDone",
}


@app.websocket("/v1/voice/agent")
async def voice_agent(ws: WebSocket) -> None:
    await ws.accept()

    if not settings.deepgram_api_key:
        await ws.send_text(_ndjson({"error": "DEEPGRAM_API_KEY is not configured."}))
        await ws.close()
        return
    if not settings.render_api_key:
        await ws.send_text(
            _ndjson({
                "error": (
                    f"No render model API key configured for render_provider="
                    f"'{settings.render_provider}'."
                )
            })
        )
        await ws.close()
        return

    # Reuse the app-wide httpx client (same one /v1/chat/stream uses) for the
    # out-of-band A2UI renders triggered by the voice agent.
    client = ws.app.state.http_client

    # First frame from Flutter carries the A2UI system prompt (persona + catalog
    # instructions, built client-side) — same payload /v1/chat/stream expects.
    try:
        config = json.loads(await ws.receive_text())
        if not isinstance(config, dict):
            raise TypeError("Configuration frame must be a JSON object.")
        system_prompt = config["system"]
    except (KeyError, TypeError, json.JSONDecodeError, WebSocketDisconnect):
        await ws.send_text(_ndjson({"error": "Expected an initial {\"system\": ...} config frame."}))
        await ws.close()
        return
    model_override = config.get("model")

    # All writes to the Flutter socket funnel through these helpers; the lock
    # keeps the listen task, render tasks, and error paths from interleaving
    # frames on the single underlying connection.
    send_lock = asyncio.Lock()

    async def send_json(obj: dict) -> None:
        async with send_lock:
            await ws.send_text(_ndjson(obj))

    async def send_audio_out(chunk: bytes) -> None:
        async with send_lock:
            await ws.send_bytes(chunk)

    session: DeepgramAgentSession | None = None
    render_tasks: set[asyncio.Task] = set()

    async def render_ui(call: Any) -> None:
        """Run the A2UI pipeline for one render_emergency_ui call, then ack it."""
        try:
            args = json.loads(call.arguments) if call.arguments else {}
        except json.JSONDecodeError:
            args = {}
        situation = args.get("situation", "")
        severity = args.get("severity")

        await send_json({"render_start": {"situation": situation, "severity": severity}})
        status = '{"status":"error"}'
        try:
            chat = ChatRequest(
                system=system_prompt,
                messages=[Message(role="user", text=situation or "Show emergency guidance.")],
                model=model_override,
            )
            content_chars = 0
            async for delta in stream_deltas(chat, client):
                content_chars += len(delta)
                await send_json({"delta": delta})
            # A 2xx stream that produced no A2UI text is a silent failure: the
            # client would show "spoke but no UI". This is almost always a
            # reasoning model (chain-of-thought lands in delta.reasoning, not
            # delta.content) or an otherwise empty completion. Surface it as an
            # error instead of a hollow `done`.
            if content_chars == 0:
                model_name = model_override or settings.render_model
                raise RuntimeError(
                    f"render model '{model_name}' returned no A2UI content "
                    "(it may be a reasoning or gated model — use a non-reasoning "
                    "instruct model such as gemini-2.5-flash or "
                    "Qwen/Qwen2.5-72B-Instruct)"
                )
            await send_json({"done": True})
            status = '{"status":"shown"}'
        except Exception as error:
            logger.exception("A2UI render failed")
            # The client may already be gone (this render runs as a background
            # task); never let a failed error-send mask the original failure.
            with contextlib.suppress(Exception):
                await send_json({"error": f"A2UI render failed: {error}"})
        finally:
            if session is not None:
                with contextlib.suppress(Exception):
                    await session.send_function_call_response(
                        call_id=call.id, name=call.name, content=status
                    )

    async def on_agent_event(msg: Any) -> None:
        # Binary frame = a chunk of TTS audio; relay straight through.
        if isinstance(msg, bytes):
            await send_audio_out(msg)
            return

        msg_type = getattr(msg, "type", None)
        if msg_type == "FunctionCallRequest":
            for call in getattr(msg, "functions", []) or []:
                if call.name == RENDER_FUNCTION_NAME:
                    for active_task in list(render_tasks):
                        active_task.cancel()
                    task = asyncio.create_task(render_ui(call))
                    render_tasks.add(task)
                    task.add_done_callback(render_tasks.discard)
                elif call.name == CALL_EMERGENCY_FUNCTION_NAME:
                    await send_json({"action": "call_emergency"})
                    if session is not None:
                        with contextlib.suppress(Exception):
                            await session.send_function_call_response(
                                call_id=call.id,
                                name=call.name,
                                content='{"status":"dialing"}',
                            )
        elif msg_type == "ConversationText":
            await send_json(
                {"transcript": {
                    "role": getattr(msg, "role", None),
                    "content": getattr(msg, "content", None),
                }}
            )
        elif msg_type in _FORWARDED_EVENTS:
            await send_json({"event": msg_type})
        elif msg_type in ("Error", "Warning"):
            await send_json({"error": f"Deepgram {msg_type}: {getattr(msg, 'description', msg)}"})

    try:
        async with DeepgramAgentSession(on_event=on_agent_event) as opened:
            session = opened
            # Pump: mic audio (bytes) up to Deepgram; text frames are control.
            while True:
                frame = await ws.receive()
                if frame.get("type") == "websocket.disconnect":
                    break
                if (data := frame.get("bytes")) is not None:
                    await session.send_audio(data)
                # Text frames are reserved for future control messages; ignore.
    except WebSocketDisconnect:
        pass
    except Exception as error:
        logger.exception("voice agent session failed")
        with contextlib.suppress(Exception):
            await send_json({"error": f"Voice session failed: {error}"})
    finally:
        for task in list(render_tasks):
            task.cancel()
        if render_tasks:
            await asyncio.gather(*render_tasks, return_exceptions=True)
        with contextlib.suppress(Exception):
            await ws.close()
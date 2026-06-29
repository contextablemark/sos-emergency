"""Streaming client for Featherless' OpenAI-compatible chat API.

Speaks the OpenAI chat-completions streaming protocol (SSE: `data: {json}`
lines terminated by `data: [DONE]`) and re-emits just the text deltas. This is
the only place the API key is used.
"""

import json
from collections.abc import AsyncIterator

import httpx

from .config import settings
from .schemas import ChatRequest

# Map our model-agnostic roles to OpenAI chat roles.
_OPENAI_ROLE = {"user": "user", "model": "assistant"}


def _to_openai_messages(req: ChatRequest) -> list[dict]:
    messages = [{"role": "system", "content": req.system}]
    messages += [
        {"role": _OPENAI_ROLE[m.role], "content": m.text} for m in req.messages
    ]
    return messages


def _delta_from_event(event: dict) -> str | None:
    choices = event.get("choices")
    if not choices:
        return None
    return choices[0].get("delta", {}).get("content")


async def stream_deltas(
    req: ChatRequest, client: httpx.AsyncClient
) -> AsyncIterator[str]:
    """Yields raw text chunks (A2UI JSON fragments) as the model produces them.

    Raises httpx.HTTPStatusError on a non-2xx response from Featherless so the
    caller can surface 401/400/503 to the client instead of silently stalling.
    """
    payload = {
        "model": req.model or settings.render_model,
        "messages": _to_openai_messages(req),
        "stream": True,
        # Provider-specific tuning (e.g. Gemini's reasoning_effort="none").
        **settings.render_extra_payload,
    }
    headers = {
        "Authorization": f"Bearer {settings.render_api_key}",
        "Content-Type": "application/json",
    }
    url = f"{settings.render_base_url}/chat/completions"

    async with client.stream("POST", url, json=payload, headers=headers) as resp:
        if resp.status_code >= 400:
            body = await resp.aread()
            raise httpx.HTTPStatusError(
                body.decode("utf-8", "replace"),
                request=resp.request,
                response=resp,
            )

        async for line in resp.aiter_lines():
            line = line.strip()
            if not line or not line.startswith("data:"):
                continue
            data = line[len("data:") :].strip()
            if data == "[DONE]":
                break
            try:
                event = json.loads(data)
            except json.JSONDecodeError:
                continue
            delta = _delta_from_event(event)
            if delta:
                yield delta
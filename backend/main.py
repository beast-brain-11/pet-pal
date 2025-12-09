# PetPal AI Backend - Gemini Live API WebSocket Server
# Real-time audio/video streaming for voice and video consultations

import asyncio
import json
import base64
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import google.generativeai as genai
from google import genai as genai_live

# Initialize FastAPI app
app = FastAPI(title="PetPal AI Backend", version="1.0.0")

# CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Keys - TODO: Move to environment variables
GEMINI_API_KEY = "AIzaSyCJn9MtZX02X_Yu5ni4cdT_44B9qT9KoEc"
MEM0_API_KEY = "m0-7oUiXeMJ8qiHWSGfdwwgSnJO1YM0TgmjdMT2PSds"

# Configure Gemini
genai.configure(api_key=GEMINI_API_KEY)

# Models
LIVE_MODEL = "models/gemini-2.5-flash-native-audio-preview-09-2025"
TEXT_MODEL = "gemini-flash-lite-latest"

# Active sessions
active_sessions = {}


class TextRequest(BaseModel):
    message: str
    dog_name: str
    dog_breed: str = ""
    dog_age: str = "adult"
    health_context: dict = {}
    memory_context: str = ""


class TextResponse(BaseModel):
    response: str
    session_id: str


# =============================================================================
# TEXT MODE ENDPOINT
# =============================================================================

@app.post("/health/text", response_model=TextResponse)
async def text_consultation(request: TextRequest):
    """Text-based health consultation (non-streaming)"""
    try:
        model = genai.GenerativeModel(TEXT_MODEL)
        
        prompt = _build_health_prompt(
            user_message=request.message,
            dog_name=request.dog_name,
            breed=request.dog_breed,
            age=request.dog_age,
            health_context=request.health_context,
            memory_context=request.memory_context,
        )
        
        response = model.generate_content(prompt)
        
        return TextResponse(
            response=response.text,
            session_id="text_" + str(hash(request.message))[:8]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# VOICE MODE - WebSocket with Gemini Live API
# =============================================================================

@app.websocket("/ws/voice/{session_id}")
async def voice_websocket(websocket: WebSocket, session_id: str):
    """Real-time voice consultation using Gemini Live API"""
    await websocket.accept()
    
    try:
        # Initialize Gemini Live client
        client = genai_live.Client(api_key=GEMINI_API_KEY)
        
        config = {
            "response_modalities": ["AUDIO"],
            "system_instruction": _build_voice_system_prompt(),
        }
        
        async with client.aio.live.connect(model=LIVE_MODEL, config=config) as session:
            active_sessions[session_id] = session
            
            # Send ready signal
            await websocket.send_text(json.dumps({"type": "ready"}))
            
            # Create tasks for bidirectional streaming
            receive_task = asyncio.create_task(
                _receive_from_client(websocket, session)
            )
            send_task = asyncio.create_task(
                _send_to_client(websocket, session)
            )
            
            # Run until one completes or errors
            done, pending = await asyncio.wait(
                [receive_task, send_task],
                return_when=asyncio.FIRST_COMPLETED
            )
            
            # Cancel pending tasks
            for task in pending:
                task.cancel()
                
    except WebSocketDisconnect:
        print(f"Voice session {session_id} disconnected")
    except Exception as e:
        print(f"Voice error: {e}")
        await websocket.send_text(json.dumps({"type": "error", "message": str(e)}))
    finally:
        active_sessions.pop(session_id, None)


async def _receive_from_client(websocket: WebSocket, session):
    """Receive audio from client and forward to Gemini"""
    while True:
        try:
            data = await websocket.receive_bytes()
            # Forward PCM audio to Gemini
            await session.send_realtime_input(
                audio={"data": data, "mime_type": "audio/pcm"}
            )
        except WebSocketDisconnect:
            break


async def _send_to_client(websocket: WebSocket, session):
    """Receive audio from Gemini and forward to client"""
    while True:
        try:
            turn = session.receive()
            async for response in turn:
                if response.server_content and response.server_content.model_turn:
                    for part in response.server_content.model_turn.parts:
                        if part.inline_data and isinstance(part.inline_data.data, bytes):
                            # Send audio back to client
                            await websocket.send_bytes(part.inline_data.data)
        except Exception as e:
            print(f"Send error: {e}")
            break


# =============================================================================
# VIDEO MODE - WebSocket with Gemini Live API
# =============================================================================

@app.websocket("/ws/video/{session_id}")
async def video_websocket(websocket: WebSocket, session_id: str):
    """Real-time video + audio consultation"""
    await websocket.accept()
    
    try:
        client = genai_live.Client(api_key=GEMINI_API_KEY)
        
        config = {
            "response_modalities": ["AUDIO"],
            "system_instruction": _build_video_system_prompt(),
        }
        
        async with client.aio.live.connect(model=LIVE_MODEL, config=config) as session:
            active_sessions[session_id] = session
            await websocket.send_text(json.dumps({"type": "ready"}))
            
            while True:
                try:
                    message = await websocket.receive_text()
                    data = json.loads(message)
                    
                    if data["type"] == "audio":
                        # Forward audio
                        audio_bytes = base64.b64decode(data["data"])
                        await session.send_realtime_input(
                            audio={"data": audio_bytes, "mime_type": "audio/pcm"}
                        )
                        
                    elif data["type"] == "video_frame":
                        # Forward video frame
                        frame_bytes = base64.b64decode(data["data"])
                        await session.send_realtime_input(
                            media_chunks=[{
                                "data": frame_bytes,
                                "mime_type": "image/jpeg"
                            }]
                        )
                        
                    # Receive and forward audio response
                    turn = session.receive()
                    async for response in turn:
                        if response.server_content and response.server_content.model_turn:
                            for part in response.server_content.model_turn.parts:
                                if part.inline_data and isinstance(part.inline_data.data, bytes):
                                    audio_b64 = base64.b64encode(part.inline_data.data).decode()
                                    await websocket.send_text(json.dumps({
                                        "type": "audio",
                                        "data": audio_b64
                                    }))
                                    
                except WebSocketDisconnect:
                    break
                    
    except Exception as e:
        print(f"Video error: {e}")
    finally:
        active_sessions.pop(session_id, None)


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def _build_health_prompt(
    user_message: str,
    dog_name: str,
    breed: str,
    age: str,
    health_context: dict,
    memory_context: str
) -> str:
    """Build health consultation prompt"""
    
    prompt = f"""You are a friendly AI veterinary assistant. Be brief and conversational.

DOG: {dog_name} ({breed}, {age})

{f"HEALTH INFO: Allergies: {health_context.get('allergies', [])}, Medications: {health_context.get('medications', [])}" if health_context else ""}

{memory_context if memory_context else ""}

USER: {user_message}

RULES:
- 2-3 short sentences maximum
- No markdown, no bullet points
- Friendly, conversational tone
- Say "see a vet" if serious
"""
    return prompt


def _build_voice_system_prompt() -> str:
    """System prompt for voice mode"""
    return """You are a friendly AI veterinary assistant having a voice conversation.

RULES:
- Speak conversationally, like talking to a friend
- Keep responses to 2-3 sentences
- Be warm and caring
- If something sounds serious, suggest seeing a vet
- Confirm you heard them correctly before giving advice
"""


def _build_video_system_prompt() -> str:
    """System prompt for video mode"""
    return """You are a friendly AI veterinary assistant. The user is showing you their pet via video.

RULES:
- Describe briefly what you see
- Keep responses to 2-3 sentences  
- Be warm and reassuring
- If you see concerning symptoms, suggest a vet visit
- Focus on what's visible and relevant
"""


# =============================================================================
# HEALTH CHECK
# =============================================================================

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model": LIVE_MODEL}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

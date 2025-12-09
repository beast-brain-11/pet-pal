# PetPal AI Backend - HuggingFace Spaces Deployment
# FastAPI + WebSocket for Gemini Live API real-time streaming

import asyncio
import json
import base64
import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import Optional
import google.generativeai as genai

# ============================================================================
# CONFIGURATION
# ============================================================================

# Get API key from environment variable (set in HF Spaces secrets)
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
MEM0_API_KEY = os.environ.get("MEM0_API_KEY", "")

# Configure Gemini
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

# Models
TEXT_MODEL = "gemini-2.0-flash-lite"
LIVE_MODEL = "models/gemini-2.5-flash-native-audio-preview-09-2025"

# ============================================================================
# FASTAPI APP
# ============================================================================

app = FastAPI(
    title="PetPal AI Backend",
    description="Real-time AI Vet consultation using Gemini",
    version="1.0.0"
)

# CORS - Allow all origins for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Active WebSocket sessions
active_sessions = {}

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class TextRequest(BaseModel):
    message: str
    dog_name: str
    dog_breed: str = ""
    dog_age: str = "adult"
    health_context: dict = {}
    memory_context: str = ""
    consultation_type: str = "text"


class TextResponse(BaseModel):
    response: str
    session_id: str


# ============================================================================
# HEALTH CHECK & HOME
# ============================================================================

@app.get("/", response_class=HTMLResponse)
async def home():
    """Home page with API info"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>PetPal AI Backend</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
            h1 { color: #6366F1; }
            .endpoint { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }
            code { background: #e0e0e0; padding: 2px 6px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>🐕 PetPal AI Backend</h1>
        <p>Real-time AI Vet consultation powered by Gemini</p>
        
        <h2>Endpoints</h2>
        <div class="endpoint">
            <strong>GET /health</strong> - Health check
        </div>
        <div class="endpoint">
            <strong>POST /health/text</strong> - Text consultation
        </div>
        <div class="endpoint">
            <strong>WS /ws/voice/{session_id}</strong> - Voice streaming
        </div>
        <div class="endpoint">
            <strong>WS /ws/video/{session_id}</strong> - Video + Voice streaming
        </div>
        
        <h2>Status</h2>
        <p>✅ Server is running</p>
        <p>API Key configured: <strong>""" + ("Yes" if GEMINI_API_KEY else "No - Set GEMINI_API_KEY secret") + """</strong></p>
    </body>
    </html>
    """


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model": TEXT_MODEL,
        "api_key_configured": bool(GEMINI_API_KEY)
    }


# ============================================================================
# TEXT CONSULTATION
# ============================================================================

@app.post("/health/text", response_model=TextResponse)
async def text_consultation(request: TextRequest):
    """Text-based health consultation"""
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not configured")
    
    try:
        model = genai.GenerativeModel(TEXT_MODEL)
        
        prompt = build_health_prompt(
            user_message=request.message,
            dog_name=request.dog_name,
            breed=request.dog_breed,
            age=request.dog_age,
            health_context=request.health_context,
            memory_context=request.memory_context,
            consultation_type=request.consultation_type,
        )
        
        response = model.generate_content(prompt)
        
        return TextResponse(
            response=response.text,
            session_id=f"text_{hash(request.message) % 100000}"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# VOICE WEBSOCKET
# ============================================================================

@app.websocket("/ws/voice/{session_id}")
async def voice_websocket(websocket: WebSocket, session_id: str):
    """Real-time voice consultation"""
    await websocket.accept()
    
    try:
        # Send ready signal
        await websocket.send_text(json.dumps({
            "type": "ready",
            "message": "Voice session started. Note: Full audio streaming requires Gemini Live API async client."
        }))
        
        active_sessions[session_id] = {"type": "voice", "websocket": websocket}
        
        while True:
            try:
                # Receive audio data
                data = await websocket.receive_bytes()
                
                # For now, acknowledge receipt
                # Full implementation requires google-genai async library
                await websocket.send_text(json.dumps({
                    "type": "audio_received",
                    "bytes": len(data)
                }))
                
            except WebSocketDisconnect:
                break
                
    except Exception as e:
        await websocket.send_text(json.dumps({"type": "error", "message": str(e)}))
    finally:
        active_sessions.pop(session_id, None)


# ============================================================================
# VIDEO WEBSOCKET
# ============================================================================

@app.websocket("/ws/video/{session_id}")
async def video_websocket(websocket: WebSocket, session_id: str):
    """Real-time video + voice consultation"""
    await websocket.accept()
    
    try:
        await websocket.send_text(json.dumps({
            "type": "ready",
            "message": "Video session started"
        }))
        
        active_sessions[session_id] = {"type": "video", "websocket": websocket}
        
        while True:
            try:
                message = await websocket.receive_text()
                data = json.loads(message)
                
                if data["type"] == "video_frame":
                    # Acknowledge video frame
                    await websocket.send_text(json.dumps({
                        "type": "frame_received"
                    }))
                    
                elif data["type"] == "text_query":
                    # Handle text query with video context
                    if GEMINI_API_KEY:
                        model = genai.GenerativeModel(TEXT_MODEL)
                        prompt = build_health_prompt(
                            user_message=data.get("message", ""),
                            dog_name=data.get("dog_name", "Your dog"),
                            breed=data.get("breed", ""),
                            age=data.get("age", "adult"),
                            consultation_type="video"
                        )
                        response = model.generate_content(prompt)
                        await websocket.send_text(json.dumps({
                            "type": "text_response",
                            "data": response.text
                        }))
                        
            except WebSocketDisconnect:
                break
                
    except Exception as e:
        await websocket.send_text(json.dumps({"type": "error", "message": str(e)}))
    finally:
        active_sessions.pop(session_id, None)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def build_health_prompt(
    user_message: str,
    dog_name: str,
    breed: str = "",
    age: str = "adult",
    health_context: dict = None,
    memory_context: str = "",
    consultation_type: str = "text"
) -> str:
    """Build health consultation prompt"""
    
    # Mode-specific intro
    mode_intro = {
        "emergency": "🚨 EMERGENCY MODE: Be direct and action-oriented. Give first aid steps.",
        "video": "📹 VIDEO MODE: The user may describe visible symptoms.",
        "voice": "📞 VOICE MODE: Respond conversationally.",
        "text": "💬 TEXT MODE: Be helpful and concise."
    }.get(consultation_type, "")
    
    # Health context
    health_info = ""
    if health_context:
        allergies = health_context.get("allergies", [])
        medications = health_context.get("medications", [])
        if allergies:
            health_info += f"⚠️ Allergies: {', '.join(allergies)}\n"
        if medications:
            health_info += f"💊 Medications: {', '.join(medications)}\n"
    
    prompt = f"""You are a friendly AI veterinary assistant.

{mode_intro}

DOG: {dog_name}
{f"Breed: {breed}" if breed else ""}
Age: {age}
{health_info}

{f"PAST CONTEXT: {memory_context}" if memory_context else ""}

USER: {user_message}

RESPONSE RULES:
- Keep response to 2-3 SHORT sentences
- Use simple, conversational language
- NO markdown, NO bullet points, NO headers
- Be warm and caring but brief
- If serious, say "Please see a vet" at the end
"""
    return prompt


# ============================================================================
# RUN SERVER
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)

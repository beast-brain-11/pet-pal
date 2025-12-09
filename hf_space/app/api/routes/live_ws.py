# Live Session WebSocket - Real-time Speech-to-Speech with Gemini Live API
# Bidirectional audio streaming with optional video

import asyncio
import base64
import json
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types

from app.config import GOOGLE_API_KEY, GEMINI_LIVE_MODEL

router = APIRouter()

# Initialize Genai client
client = genai.Client(api_key=GOOGLE_API_KEY) if GOOGLE_API_KEY else None

# Vet system prompt for voice mode
VET_SYSTEM_PROMPT = """You are a friendly AI veterinary assistant for PetPal. 

VOICE MODE RULES:
- Speak naturally and conversationally, like a caring vet
- Keep responses brief (1-3 sentences) since this is voice
- Be warm, reassuring, and helpful
- If you see concerning symptoms in video, mention them gently
- Always recommend seeing a real vet for serious issues
- Never diagnose definitively - give guidance only

CONTEXT:
You are speaking with a pet owner about their dog's health.
Answer their questions helpfully and ask follow-up questions if needed.
"""


@router.websocket("/ws/live")
async def live_session(websocket: WebSocket):
    """Real-time bidirectional audio streaming with Gemini Live API
    
    Flutter sends:
    {
        "type": "audio",
        "data": "<base64 PCM 16-bit 16kHz mono>"
    }
    OR
    {
        "type": "video",
        "data": "<base64 JPEG frame>"
    }
    OR
    {
        "type": "config",
        "dog_name": "...",
        "dog_id": "..."
    }
    
    Backend sends:
    {
        "type": "audio",
        "data": "<base64 PCM 16-bit 24kHz mono>"
    }
    AND
    {
        "type": "transcript",
        "role": "user" | "assistant",
        "text": "..."
    }
    """
    await websocket.accept()
    
    if not client:
        await websocket.send_json({
            "type": "error",
            "message": "Gemini API not configured"
        })
        await websocket.close()
        return
    
    # Session state
    dog_name = "your dog"
    dog_id = "default"
    is_running = True
    
    try:
        # Send initial connection message
        await websocket.send_json({
            "type": "connected",
            "message": "Live session ready. Start speaking!"
        })
        
        # Connect to Gemini Live API
        config = types.LiveConnectConfig(
            response_modalities=["AUDIO", "TEXT"],
            system_instruction=types.Content(
                parts=[types.Part(text=VET_SYSTEM_PROMPT)]
            ),
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name="Puck"  # Friendly voice
                    )
                )
            )
        )
        
        async with client.aio.live.connect(
            model=GEMINI_LIVE_MODEL,
            config=config
        ) as live:
            
            async def receive_from_flutter():
                """Receive audio/video from Flutter and send to Gemini"""
                nonlocal dog_name, dog_id, is_running
                
                while is_running:
                    try:
                        data = await websocket.receive_json()
                        msg_type = data.get("type")
                        
                        if msg_type == "config":
                            dog_name = data.get("dog_name", "your dog")
                            dog_id = data.get("dog_id", "default")
                            
                        elif msg_type == "audio":
                            # Decode base64 PCM audio and send to Gemini
                            # Using dict format as per official docs
                            audio_bytes = base64.b64decode(data["data"])
                            await live.send_realtime_input(
                                audio={"data": audio_bytes, "mime_type": "audio/pcm"}
                            )
                            
                        elif msg_type == "video":
                            # Decode base64 JPEG and send to Gemini
                            video_bytes = base64.b64decode(data["data"])
                            await live.send_realtime_input(
                                video={"data": video_bytes, "mime_type": "image/jpeg"}
                            )
                            
                        elif msg_type == "stop":
                            is_running = False
                            break
                            
                    except WebSocketDisconnect:
                        is_running = False
                        break
                    except Exception as e:
                        print(f"Receive error: {e}")
            
            async def send_to_flutter():
                """Receive audio/text from Gemini and send to Flutter"""
                nonlocal is_running
                
                while is_running:
                    try:
                        turn = live.receive()
                        async for response in turn:
                            if not is_running:
                                break
                                
                            if response.server_content:
                                content = response.server_content
                                
                                # Handle model turn (audio + text)
                                if content.model_turn:
                                    for part in content.model_turn.parts:
                                        # Audio data
                                        if part.inline_data and isinstance(part.inline_data.data, bytes):
                                            audio_b64 = base64.b64encode(part.inline_data.data).decode()
                                            await websocket.send_json({
                                                "type": "audio",
                                                "data": audio_b64
                                            })
                                        
                                        # Text transcript
                                        if part.text:
                                            await websocket.send_json({
                                                "type": "transcript",
                                                "role": "assistant",
                                                "text": part.text
                                            })
                                
                                # Handle input transcript (user's speech as text)
                                if hasattr(content, 'input_transcript') and content.input_transcript:
                                    await websocket.send_json({
                                        "type": "transcript",
                                        "role": "user",
                                        "text": content.input_transcript
                                    })
                                    
                    except asyncio.CancelledError:
                        break
                    except Exception as e:
                        print(f"Send error: {e}")
                        if "closed" in str(e).lower():
                            break
            
            # Run both tasks concurrently
            try:
                async with asyncio.TaskGroup() as tg:
                    tg.create_task(receive_from_flutter())
                    tg.create_task(send_to_flutter())
            except* Exception as eg:
                for e in eg.exceptions:
                    print(f"Task error: {e}")
                    
    except WebSocketDisconnect:
        print("Live session disconnected")
    except Exception as e:
        print(f"Live session error: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": str(e)
            })
        except:
            pass
    finally:
        print("Live session ended")

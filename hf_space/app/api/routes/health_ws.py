# WebSocket Routes for Health Features
# /ws/consultation, /ws/prescription, /ws/vaccination

import json
import uuid
import asyncio
from datetime import datetime
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types

from app.config import GOOGLE_API_KEY, GEMINI_MODEL
from app.services.prompt_builder import (
    build_consultation_prompt,
    build_prescription_prompt,
    build_vaccination_prompt
)

router = APIRouter()

# Initialize Genai client
client = genai.Client(api_key=GOOGLE_API_KEY) if GOOGLE_API_KEY else None

# Active sessions
active_sessions = {}

# ============================================================================
# /ws/consultation - Main health consultation endpoint
# ============================================================================

@router.websocket("/ws/consultation")
async def consultation_websocket(websocket: WebSocket):
    """Real-time health consultation with AI
    
    Input: {
        mode: "text"|"voice"|"video"|"emergency",
        message: str,
        dog_id: str,
        consultation_id: str,
        dog_name: str,
        breed: str,
        age: str,
        weight: str
    }
    
    Output: {
        role: "assistant",
        text: str,
        audio: str|null (base64),
        entities: {symptoms: [], conditions: []}
    }
    """
    await websocket.accept()
    session_id = str(uuid.uuid4())
    active_sessions[session_id] = {"type": "consultation", "created": datetime.now()}
    
    # Get Mem0 service from app state
    mem0_service = websocket.app.state.mem0_service if hasattr(websocket.app.state, 'mem0_service') else None
    
    try:
        await websocket.send_json({
            "type": "connected",
            "session_id": session_id,
            "message": "Welcome to PetPal Health! How can I help your furry friend today?"
        })
        
        while True:
            # Receive message
            data = await websocket.receive_json()
            
            mode = data.get("mode", "text")
            message = data.get("message", "")
            dog_id = data.get("dog_id", "default")
            consultation_id = data.get("consultation_id", session_id)
            dog_name = data.get("dog_name", "Your dog")
            breed = data.get("breed", "")
            age = data.get("age", "adult")
            weight = data.get("weight", "")
            
            if not message:
                await websocket.send_json({
                    "type": "error",
                    "message": "No message provided"
                })
                continue
            
            # Get health context from Mem0
            health_context = ""
            if mem0_service:
                try:
                    health_context = await mem0_service.get_health_context(dog_id, message)
                    # Store user message
                    await mem0_service.add_consultation_memory(
                        dog_id=dog_id,
                        consultation_id=consultation_id,
                        message=message,
                        role="user"
                    )
                except Exception as e:
                    print(f"Mem0 error: {e}")
            
            # Build prompt
            prompt = build_consultation_prompt(
                dog_name=dog_name,
                breed=breed,
                age=age,
                weight=weight,
                health_context=health_context,
                user_query=message,
                mode=mode
            )
            
            # Get AI response
            try:
                if client:
                    response = client.models.generate_content(
                        model=GEMINI_MODEL,
                        contents=prompt
                    )
                    ai_text = response.text
                else:
                    ai_text = "I'm sorry, the AI service is not configured. Please check the API key."
                
                # Store AI response to Mem0
                if mem0_service:
                    try:
                        await mem0_service.add_consultation_memory(
                            dog_id=dog_id,
                            consultation_id=consultation_id,
                            message=ai_text,
                            role="assistant"
                        )
                    except Exception as e:
                        print(f"Mem0 store error: {e}")
                
                # Send response
                await websocket.send_json({
                    "type": "response",
                    "role": "assistant",
                    "text": ai_text,
                    "audio": None,  # Audio streaming to be implemented
                    "entities": {
                        "symptoms": [],
                        "conditions": []
                    }
                })
                
            except Exception as e:
                await websocket.send_json({
                    "type": "error",
                    "message": f"AI error: {str(e)}"
                })
                
    except WebSocketDisconnect:
        print(f"Consultation session {session_id} disconnected")
    finally:
        active_sessions.pop(session_id, None)


# ============================================================================
# /ws/prescription - Medication management
# ============================================================================

@router.websocket("/ws/prescription")
async def prescription_websocket(websocket: WebSocket):
    """Prescription management and interaction checking
    
    Input: {
        action: "add"|"list"|"check_interaction",
        medication: str,
        dosage: str,
        frequency: str,
        dog_id: str
    }
    
    Output: {
        medication: str,
        interactions: str,
        safe_to_prescribe: bool
    }
    """
    await websocket.accept()
    session_id = str(uuid.uuid4())
    
    mem0_service = websocket.app.state.mem0_service if hasattr(websocket.app.state, 'mem0_service') else None
    
    try:
        await websocket.send_json({
            "type": "connected",
            "session_id": session_id,
            "message": "Prescription management ready"
        })
        
        while True:
            data = await websocket.receive_json()
            
            action = data.get("action", "list")
            medication = data.get("medication", "")
            dosage = data.get("dosage", "")
            frequency = data.get("frequency", "")
            dog_id = data.get("dog_id", "default")
            dog_name = data.get("dog_name", "Your dog")
            
            if action == "add":
                # Add new medication
                if mem0_service and medication:
                    await mem0_service.add_medication(dog_id, medication, dosage, frequency)
                
                await websocket.send_json({
                    "type": "response",
                    "action": "added",
                    "medication": medication,
                    "message": f"Added {medication} to {dog_name}'s prescriptions"
                })
                
            elif action == "list":
                # List all medications
                medications = []
                if mem0_service:
                    meds = await mem0_service.get_medications(dog_id)
                    medications = [m.get("memory", "") for m in meds]
                
                await websocket.send_json({
                    "type": "response",
                    "action": "list",
                    "medications": medications
                })
                
            elif action == "check_interaction":
                # Check drug interactions
                current_meds = []
                if mem0_service:
                    meds = await mem0_service.get_medications(dog_id)
                    current_meds = [m.get("memory", "") for m in meds]
                
                # Use AI to check interactions
                if client and medication:
                    prompt = build_prescription_prompt(
                        dog_name=dog_name,
                        current_medications=current_meds,
                        new_medication=medication,
                        dosage=dosage
                    )
                    
                    response = client.models.generate_content(
                        model=GEMINI_MODEL,
                        contents=prompt
                    )
                    
                    interaction_text = response.text
                    safe = "SAFE" in interaction_text.upper()
                    
                    await websocket.send_json({
                        "type": "response",
                        "action": "interaction_check",
                        "medication": medication,
                        "interactions": interaction_text,
                        "safe_to_prescribe": safe
                    })
                else:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Cannot check interactions - AI not configured"
                    })
                    
    except WebSocketDisconnect:
        print(f"Prescription session {session_id} disconnected")


# ============================================================================
# /ws/vaccination - Vaccination tracking
# ============================================================================

@router.websocket("/ws/vaccination")
async def vaccination_websocket(websocket: WebSocket):
    """Vaccination tracking and reminders
    
    Input: {
        action: "add"|"list"|"booster_due",
        vaccine: str,
        date: str,
        vet: str,
        dog_id: str
    }
    
    Output: {
        vaccine: str,
        next_booster: str,
        reminder_days: int
    }
    """
    await websocket.accept()
    session_id = str(uuid.uuid4())
    
    mem0_service = websocket.app.state.mem0_service if hasattr(websocket.app.state, 'mem0_service') else None
    
    try:
        await websocket.send_json({
            "type": "connected",
            "session_id": session_id,
            "message": "Vaccination tracking ready"
        })
        
        while True:
            data = await websocket.receive_json()
            
            action = data.get("action", "list")
            vaccine = data.get("vaccine", "")
            date = data.get("date", "")
            vet = data.get("vet", "")
            dog_id = data.get("dog_id", "default")
            dog_name = data.get("dog_name", "Your dog")
            breed = data.get("breed", "")
            age = data.get("age", "")
            
            if action == "add":
                # Add vaccination record
                if mem0_service and vaccine:
                    await mem0_service.add_vaccination(dog_id, vaccine, date, vet)
                
                await websocket.send_json({
                    "type": "response",
                    "action": "added",
                    "vaccine": vaccine,
                    "date": date,
                    "message": f"Recorded {vaccine} vaccination for {dog_name}"
                })
                
            elif action == "list":
                # List vaccination history
                vaccinations = []
                if mem0_service:
                    vaxs = await mem0_service.get_vaccinations(dog_id)
                    vaccinations = [v.get("memory", "") for v in vaxs]
                
                await websocket.send_json({
                    "type": "response",
                    "action": "list",
                    "vaccinations": vaccinations
                })
                
            elif action == "booster_due":
                # Calculate next boosters
                vaccination_history = []
                if mem0_service:
                    vaxs = await mem0_service.get_vaccinations(dog_id)
                    vaccination_history = [v.get("memory", "") for v in vaxs]
                
                # Use AI to calculate boosters
                if client:
                    prompt = build_vaccination_prompt(
                        dog_name=dog_name,
                        breed=breed,
                        age=age,
                        vaccination_history=vaccination_history,
                        action="calculate next boosters"
                    )
                    
                    response = client.models.generate_content(
                        model=GEMINI_MODEL,
                        contents=prompt
                    )
                    
                    await websocket.send_json({
                        "type": "response",
                        "action": "booster_schedule",
                        "schedule": response.text
                    })
                else:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Cannot calculate boosters - AI not configured"
                    })
                    
    except WebSocketDisconnect:
        print(f"Vaccination session {session_id} disconnected")

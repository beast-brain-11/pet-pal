# PetPal Health Backend - Main FastAPI Server
# Google ADK Multi-Agent + Mem0 + WebSocket Streaming

import os
import asyncio
import json
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from dotenv import load_dotenv

load_dotenv()

# Import our services and agents
from app.agents.coordinator_agent import create_health_coordinator
from app.services.mem0_health_service import Mem0HealthService
from app.api.routes.health_ws import router as health_router
from app.api.routes.live_ws import router as live_router

# ============================================================================
# LIFESPAN - Initialize services on startup
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize services on startup, cleanup on shutdown"""
    print("🚀 Starting PetPal AI Backend...")
    
    # Initialize Mem0 service
    app.state.mem0_service = Mem0HealthService()
    
    # Initialize ADK coordinator agent
    app.state.coordinator = create_health_coordinator()
    
    print("✅ Services initialized")
    yield
    
    print("👋 Shutting down PetPal AI Backend")

# ============================================================================
# FASTAPI APP
# ============================================================================

app = FastAPI(
    title="PetPal AI Health Backend",
    description="Multi-Agent AI Vet powered by Google ADK + Mem0",
    version="2.0.0",
    lifespan=lifespan
)

# CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include WebSocket routes
app.include_router(health_router)
app.include_router(live_router)

# ============================================================================
# HOME & HEALTH CHECK
# ============================================================================

@app.get("/", response_class=HTMLResponse)
async def home():
    """Home page with API info"""
    api_key = bool(os.environ.get("GOOGLE_API_KEY"))
    mem0_key = bool(os.environ.get("MEM0_API_KEY"))
    
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>PetPal AI Backend</title>
        <style>
            body {{ font-family: system-ui; max-width: 800px; margin: 50px auto; padding: 20px; background: #1a1a2e; color: #eee; }}
            h1 {{ color: #a855f7; }}
            .status {{ padding: 8px 16px; border-radius: 8px; display: inline-block; margin: 4px 0; }}
            .ok {{ background: #22c55e20; color: #22c55e; }}
            .err {{ background: #ef444420; color: #ef4444; }}
            .endpoint {{ background: #ffffff10; padding: 12px; margin: 8px 0; border-radius: 8px; font-family: monospace; }}
        </style>
    </head>
    <body>
        <h1>🐕 PetPal AI Health Backend v2.0</h1>
        <p>Multi-Agent AI Vet powered by Google ADK + Mem0</p>
        
        <h2>Status</h2>
        <p class="status {'ok' if api_key else 'err'}">{'✅' if api_key else '❌'} GOOGLE_API_KEY</p><br>
        <p class="status {'ok' if mem0_key else 'err'}">{'✅' if mem0_key else '❌'} MEM0_API_KEY</p>
        
        <h2>Agents</h2>
        <p>🎯 <strong>Coordinator</strong> - Routes requests</p>
        <p>🏥 <strong>Health Specialist</strong> - Consultations</p>
        <p>🚨 <strong>Emergency</strong> - Crisis response</p>
        
        <h2>WebSocket Endpoints</h2>
        <div class="endpoint">ws://host/ws/live 🎤 Real-time voice/video</div>
        <div class="endpoint">ws://host/ws/consultation</div>
        <div class="endpoint">ws://host/ws/prescription</div>
        <div class="endpoint">ws://host/ws/vaccination</div>
        
        <h2>REST Endpoints</h2>
        <div class="endpoint">GET /health</div>
    </body>
    </html>
    """

@app.get("/health")
async def health_check():
    """Health check endpoint for HF Spaces"""
    return {
        "status": "ok",
        "service": "petpal-health-backend",
        "version": "2.0.0",
        "agents": ["coordinator", "health_specialist", "emergency"],
        "google_api_key": bool(os.environ.get("GOOGLE_API_KEY")),
        "mem0_api_key": bool(os.environ.get("MEM0_API_KEY"))
    }

# ============================================================================
# RUN SERVER
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)

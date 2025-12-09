---
title: PetPal AI Health Backend
emoji: 🐕
colorFrom: purple
colorTo: blue
sdk: docker
pinned: false
license: mit
app_port: 7860
---

# PetPal AI Health Backend v2.0

Multi-Agent AI Vet powered by **Google ADK + Mem0**

## Agents

| Agent | Role |
|-------|------|
| 🎯 Coordinator | Routes requests to specialists |
| 🏥 Health Specialist | Consultations, symptoms, medications |
| 🚨 Emergency | Crisis response, first aid |

## WebSocket Endpoints

| Endpoint | Description |
|----------|-------------|
| `/ws/consultation` | Health consultations (text/voice/video/emergency) |
| `/ws/prescription` | Medication management + interactions |
| `/ws/vaccination` | Vaccination tracking + reminders |

## REST Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Home page |
| `GET /health` | Health check |

## Setup

Add these secrets in HuggingFace Spaces settings:
- `GOOGLE_API_KEY` - Your Gemini API key
- `MEM0_API_KEY` - Your Mem0 API key

## Features

- ✅ Real-time WebSocket streaming
- ✅ Persistent memory per dog (Mem0)
- ✅ Multi-agent routing
- ✅ Emergency detection
- ✅ Drug interaction checking
- ✅ Vaccination scheduling

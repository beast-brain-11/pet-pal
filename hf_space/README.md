---
title: PetPal AI Backend
emoji: 🐕
colorFrom: purple
colorTo: blue
sdk: docker
pinned: false
license: mit
app_port: 7860
---

# PetPal AI Backend

Real-time AI Vet consultation powered by Gemini.

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Home page |
| `/health` | GET | Health check |
| `/health/text` | POST | Text consultation |
| `/ws/voice/{session_id}` | WebSocket | Voice streaming |
| `/ws/video/{session_id}` | WebSocket | Video streaming |

## Setup

Add your `GEMINI_API_KEY` in the Secrets section of your Space settings.

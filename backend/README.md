# PetPal AI Backend

Real-time voice and video AI vet consultation using Gemini 2.5 Flash Live API.

## Setup

```bash
cd backend
pip install -r requirements.txt
python main.py
```

Server runs on `http://localhost:8000`

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health/text` | POST | Text consultation |
| `/ws/voice/{session_id}` | WebSocket | Real-time voice |
| `/ws/video/{session_id}` | WebSocket | Real-time video + voice |
| `/health` | GET | Health check |

## Audio Format

- **Input**: 16-bit PCM, 16kHz, mono
- **Output**: 16-bit PCM, 24kHz, mono

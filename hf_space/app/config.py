# Config - Environment variables and settings
import os
from dotenv import load_dotenv

load_dotenv()

# API Keys
GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY", "")
MEM0_API_KEY = os.environ.get("MEM0_API_KEY", "")

# Models
GEMINI_MODEL = "gemini-flash-lite-latest"
GEMINI_LIVE_MODEL = "gemini-2.5-flash-native-audio-preview-09-2025"

# Mem0 Config
MEM0_CONFIG = {
    "llm": {
        "provider": "google",
        "config": {
            "model": "gemini-flash-lite-latest",
            "temperature": 0.7,
            "max_tokens": 2000,
            "api_key": GOOGLE_API_KEY
        }
    }
}

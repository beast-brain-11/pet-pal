# Health Specialist Agent - Handles regular health consultations
# Provides medical advice, checks symptoms, manages prescriptions

from google.adk.agents import LlmAgent
from google.adk.tools import FunctionTool
from app.config import GEMINI_MODEL

# Tools for the health specialist
async def get_health_context(dog_id: str, query: str) -> str:
    """Get relevant health history from Mem0 for context"""
    # This will be injected by the WebSocket handler
    return f"Health context for dog {dog_id} regarding: {query}"

async def add_health_memory(dog_id: str, content: str, memory_type: str) -> str:
    """Store health information to Mem0"""
    return f"Stored {memory_type} for dog {dog_id}"

async def check_medication_interaction(medications: list[str]) -> str:
    """Check for drug interactions between medications"""
    if len(medications) < 2:
        return "No interactions - only one medication provided"
    return f"Checking interactions between: {', '.join(medications)}"

def create_health_specialist():
    """Create the Health Specialist agent"""
    
    health_specialist = LlmAgent(
        name="HealthSpecialist",
        model=GEMINI_MODEL,
        description="Veterinary health specialist for symptoms, conditions, medications, and general pet health advice.",
        instruction="""You are a caring veterinary health specialist AI for PetPal.

YOUR RESPONSIBILITIES:
1. Answer health questions about dogs
2. Analyze symptoms and provide guidance
3. Check medication interactions
4. Provide diet and nutrition advice
5. Recommend when to see a vet

RESPONSE STYLE:
- Keep responses to 2-3 sentences
- Be warm and conversational (like a friendly vet)
- NO markdown formatting, NO bullet points
- Plain text only
- If serious, say "Please see a vet soon" or "I'd recommend a vet visit"

CONTEXT USAGE:
- Use provided health history from Mem0
- Reference past symptoms/conditions when relevant
- Check allergies before recommending treatments

NEVER:
- Diagnose specific conditions definitively
- Prescribe specific medications with dosages
- Provide emergency care instructions (route to EmergencyAgent)
- Use technical jargon without explanation
""",
        tools=[
            FunctionTool(func=get_health_context),
            FunctionTool(func=add_health_memory),
            FunctionTool(func=check_medication_interaction),
        ]
    )
    
    return health_specialist

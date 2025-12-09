# Google ADK Coordinator Agent - Central Router
# Routes requests to Health Specialist or Emergency agents

from google.adk.agents import LlmAgent
from app.config import GEMINI_MODEL
from app.agents.health_specialist_agent import create_health_specialist
from app.agents.emergency_agent import create_emergency_agent

def create_health_coordinator():
    """Create the main coordinator agent with sub-agents"""
    
    # Create specialist sub-agents
    health_specialist = create_health_specialist()
    emergency_agent = create_emergency_agent()
    
    # Create coordinator with sub-agents
    coordinator = LlmAgent(
        name="HealthCoordinator",
        model=GEMINI_MODEL,
        description="Main coordinator for pet health consultations. Routes to specialists.",
        instruction="""You are the PetPal Health Coordinator. Your role is to:

1. RECEIVE user health queries about their dog
2. ROUTE to the appropriate specialist:
   - For EMERGENCIES (bleeding, poisoning, difficulty breathing, collapse, seizures): 
     Transfer to EmergencyAgent immediately
   - For REGULAR health questions (symptoms, conditions, diet, medication):
     Transfer to HealthSpecialist

3. CONTEXT: You have access to the dog's health history via Mem0

IMPORTANT:
- Always be warm and caring
- If unsure whether it's an emergency, ask clarifying questions
- Never diagnose - always recommend vet visits for serious concerns

When routing, use: transfer_to_agent(agent_name='HealthSpecialist') or transfer_to_agent(agent_name='EmergencyAgent')
""",
        sub_agents=[health_specialist, emergency_agent]
    )
    
    return coordinator

# Prompt Builder - Constructs prompts with Mem0 context
# For health consultations, prescriptions, and vaccinations

def build_consultation_prompt(
    dog_name: str,
    breed: str,
    age: str,
    weight: str,
    health_context: str,
    user_query: str,
    mode: str = "text"
) -> str:
    """Build consultation prompt with Mem0 context"""
    
    mode_instruction = {
        "text": "Respond in plain text, 2-3 sentences max.",
        "voice": "Respond conversationally as if speaking. Keep it brief and warm.",
        "video": "The user may be showing you their pet. Describe what concerns you see if any.",
        "emergency": "This is an EMERGENCY. Provide immediate first aid steps. Be direct."
    }.get(mode, "")
    
    prompt = f"""You are a caring veterinary AI assistant for PetPal.

DOG PROFILE:
- Name: {dog_name}
- Breed: {breed}
- Age: {age}
- Weight: {weight}

{health_context}

USER QUESTION: {user_query}

INSTRUCTIONS:
{mode_instruction}
- Be warm and friendly
- Never use markdown formatting
- If serious, recommend seeing a vet
- Reference past health issues if relevant
"""
    return prompt


def build_prescription_prompt(
    dog_name: str,
    current_medications: list,
    new_medication: str,
    dosage: str
) -> str:
    """Build prescription interaction check prompt"""
    
    meds_list = "\n".join([f"- {m}" for m in current_medications]) if current_medications else "None"
    
    prompt = f"""You are checking medication interactions for {dog_name}.

CURRENT MEDICATIONS:
{meds_list}

NEW PRESCRIPTION:
- Medication: {new_medication}
- Dosage: {dosage}

TASK:
1. Check for drug interactions between current and new medications
2. Note any contraindications for dogs
3. Recommend if safe to prescribe

Respond with:
- SAFE or CAUTION or WARNING
- Brief explanation
- Any monitoring recommendations
"""
    return prompt


def build_vaccination_prompt(
    dog_name: str,
    breed: str,
    age: str,
    vaccination_history: list,
    action: str = "schedule"
) -> str:
    """Build vaccination schedule prompt"""
    
    history = "\n".join([f"- {v}" for v in vaccination_history]) if vaccination_history else "No records"
    
    prompt = f"""You are managing vaccinations for {dog_name} ({breed}, {age}).

VACCINATION HISTORY:
{history}

TASK: {action.upper()}

If calculating boosters:
- Core vaccines (Rabies, DHPP) typically every 1-3 years
- Non-core based on lifestyle (Bordetella, Lyme, etc.)

Provide:
- Next due vaccines with dates
- Any overdue vaccines
- Recommendations based on breed/age
"""
    return prompt

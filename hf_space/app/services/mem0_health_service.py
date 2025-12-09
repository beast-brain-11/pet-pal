# Mem0 Health Service - Persistent AI Memory Layer
# Uses Mem0 Cloud API (no local LLM config needed)

import os
from typing import Optional
from mem0 import MemoryClient
from app.config import MEM0_API_KEY

class Mem0HealthService:
    """Mem0 service for persistent health memory per dog"""
    
    def __init__(self):
        """Initialize Mem0 Cloud Client"""
        self.client = None
        
        if MEM0_API_KEY:
            try:
                # Use Mem0 Cloud API - no LLM config needed!
                self.client = MemoryClient(api_key=MEM0_API_KEY)
                print("✅ Mem0 Cloud initialized successfully")
            except Exception as e:
                print(f"⚠️ Mem0 init failed: {e}")
        else:
            print("⚠️ MEM0_API_KEY not set - memory disabled")
    
    async def add_consultation_memory(
        self,
        dog_id: str,
        consultation_id: str,
        message: str,
        role: str = "user",
        metadata: Optional[dict] = None
    ) -> bool:
        """Add a message to consultation memory"""
        if not self.client:
            return False
        
        try:
            mem_metadata = {
                "type": "consultation",
                "consultation_id": consultation_id,
                "role": role,
                **(metadata or {})
            }
            
            self.client.add(
                messages=[{"role": role, "content": message}],
                user_id=dog_id,
                metadata=mem_metadata
            )
            return True
        except Exception as e:
            print(f"Mem0 add error: {e}")
            return False
    
    async def get_health_context(
        self,
        dog_id: str,
        query: str,
        limit: int = 5
    ) -> str:
        """Get relevant health history for AI context injection"""
        if not self.client:
            return ""
        
        try:
            results = self.client.search(
                query=query,
                user_id=dog_id,
                limit=limit
            )
            
            if not results:
                return ""
            
            context_parts = ["Previous Health Context:"]
            for mem in results:
                memory_text = mem.get("memory", "")
                if memory_text:
                    context_parts.append(f"- {memory_text}")
            
            return "\n".join(context_parts)
        except Exception as e:
            print(f"Mem0 search error: {e}")
            return ""
    
    async def store_consultation_findings(
        self,
        dog_id: str,
        consultation_id: str,
        findings: dict
    ) -> bool:
        """Store AI findings at end of consultation"""
        if not self.client:
            return False
        
        try:
            summary = findings.get("summary", "")
            symptoms = findings.get("symptoms", [])
            conditions = findings.get("conditions", [])
            recommendations = findings.get("recommendations", [])
            
            content = f"""Consultation Summary: {summary}
Symptoms discussed: {', '.join(symptoms) if symptoms else 'None'}
Conditions identified: {', '.join(conditions) if conditions else 'None'}
Recommendations: {', '.join(recommendations) if recommendations else 'None'}"""
            
            self.client.add(
                messages=[{"role": "assistant", "content": content}],
                user_id=dog_id,
                metadata={
                    "type": "consultation_summary",
                    "consultation_id": consultation_id,
                    "symptoms": symptoms,
                    "conditions": conditions
                }
            )
            return True
        except Exception as e:
            print(f"Mem0 findings error: {e}")
            return False
    
    async def add_medication(
        self,
        dog_id: str,
        medication: str,
        dosage: str,
        frequency: str
    ) -> bool:
        """Add medication to dog's profile"""
        if not self.client:
            return False
        
        try:
            content = f"Medication prescribed: {medication}, Dosage: {dosage}, Frequency: {frequency}"
            self.client.add(
                messages=[{"role": "system", "content": content}],
                user_id=dog_id,
                metadata={"type": "medication", "name": medication, "dosage": dosage, "frequency": frequency}
            )
            return True
        except Exception as e:
            print(f"Mem0 medication error: {e}")
            return False
    
    async def add_vaccination(
        self,
        dog_id: str,
        vaccine: str,
        date: str,
        vet: str = ""
    ) -> bool:
        """Add vaccination record"""
        if not self.client:
            return False
        
        try:
            content = f"Vaccination: {vaccine} given on {date}" + (f" by {vet}" if vet else "")
            self.client.add(
                messages=[{"role": "system", "content": content}],
                user_id=dog_id,
                metadata={"type": "vaccination", "vaccine": vaccine, "date": date, "vet": vet}
            )
            return True
        except Exception as e:
            print(f"Mem0 vaccination error: {e}")
            return False
    
    async def get_medications(self, dog_id: str) -> list:
        """Get all medications for a dog"""
        if not self.client:
            return []
        
        try:
            results = self.client.search(
                query="current medications prescriptions",
                user_id=dog_id,
                limit=10
            )
            return results or []
        except Exception as e:
            print(f"Mem0 get medications error: {e}")
            return []
    
    async def get_vaccinations(self, dog_id: str) -> list:
        """Get vaccination history for a dog"""
        if not self.client:
            return []
        
        try:
            results = self.client.search(
                query="vaccinations vaccines shots",
                user_id=dog_id,
                limit=10
            )
            return results or []
        except Exception as e:
            print(f"Mem0 get vaccinations error: {e}")
            return []

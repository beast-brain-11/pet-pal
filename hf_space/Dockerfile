FROM python:3.11-slim

WORKDIR /code

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app/ ./app/

# Expose port 7860 (HuggingFace Spaces default)
EXPOSE 7860

# Run the app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]

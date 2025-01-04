FROM python:3.9-slim

WORKDIR /app

# Install required Python packages
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy the application code
COPY sqs_listener.py .

# Set the entrypoint
CMD ["python", "sqs_listener.py"]

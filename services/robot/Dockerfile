FROM python:3.11-slim
LABEL maintainer="Fleet Platform Team"
LABEL description="Fleet Robot Telemetry Service"

WORKDIR /app
COPY robot.py /app/
RUN pip install --no-cache-dir requests

# Security: Run as non-root
USER 1000
CMD ["python", "-u", "/app/robot.py"]

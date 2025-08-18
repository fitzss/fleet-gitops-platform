FROM python:3.11-slim
LABEL maintainer="Fleet Platform Team"
LABEL description="Fleet Monitor API Service"

WORKDIR /app
COPY monitor.py /app/
RUN pip install --no-cache-dir flask

# Security: Run as non-root
USER 1000
EXPOSE 8000
CMD ["python", "-u", "/app/monitor.py"]

FROM python:3.9-slim

WORKDIR /recommendation-service

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 10 --timeout 60 -r requirements.txt

COPY . .

EXPOSE 5003

CMD ["python", "app/main.py"]

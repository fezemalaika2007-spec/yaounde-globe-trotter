FROM python:3.9-slim

WORKDIR /itinerary-service

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 10 --timeout 60 -r requirements.txt

COPY . .

EXPOSE 5002

CMD ["python", "app/main.py"]


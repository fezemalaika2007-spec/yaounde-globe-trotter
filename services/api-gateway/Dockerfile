FROM python:3.12-slim

WORKDIR /gateway

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 10 --timeout 60 -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app/main.py"]

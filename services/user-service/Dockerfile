FROM python:3.9-slim

WORKDIR /user-service

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 10 --timeout 60 -r requirements.txt

COPY . .

EXPOSE 5001

CMD ["python", "app/main.py"]


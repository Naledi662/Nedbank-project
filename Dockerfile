FROM nedbank-de-challenge/base:1.0

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY pipeline/ pipeline/
COPY config/   config/

ENV PYTHONPATH=/app

CMD ["python", "pipeline/run_all.py"]

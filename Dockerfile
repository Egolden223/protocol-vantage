FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app_bundle.tar.gz /tmp/app_bundle.tar.gz
RUN tar -xzf /tmp/app_bundle.tar.gz -C /app && rm -f /tmp/app_bundle.tar.gz
ENV VANTAGE_DB_PATH=/app/data/vantage.sqlite3 \
    VANTAGE_ARTIFACTS_ROOT=/app/data/courses \
    VANTAGE_BACKUP_DIR=/app/data/backup \
    GRU_CALIBRATION_ACTIVATION=0
RUN mkdir -p /app/data/courses /app/data/backup
EXPOSE 5000
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT:-5000} --workers ${WEB_CONCURRENCY:-1} --timeout 120 app:app"]

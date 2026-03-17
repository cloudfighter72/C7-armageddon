#!/bin/bash
dnf update -y
dnf install -y python3-pip
pip3 install flask pymysql boto3 watchtower

mkdir -p /opt/rdsapp
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import time
import logging
import boto3
import pymysql
from flask import Flask, request
import watchtower

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

cloudwatch_handler = watchtower.CloudWatchLogHandler(
    log_group_name="/aws/ec2/lab-1c-rds-app",
    stream_name=f"rdsapp-instance-{int(time.time())}",  # Unique per process start
    send_interval=10,                         # Batch send every 10 seconds
    boto3_client=boto3.client('logs', region_name=os.environ.get("AWS_REGION", "sa-east-1"))
)
logger.addHandler(cloudwatch_handler)

console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(console_handler)

REGION = os.environ.get("AWS_REGION", "us-east-2")
SECRET_ID = os.environ.get("SECRET_ID", "lab/rds/mysql_v17")

secrets_client = boto3.client("secretsmanager", region_name=REGION)

def get_db_creds():
    try:
        resp = secrets_client.get_secret_value(SecretId=SECRET_ID)
        creds = json.loads(resp["SecretString"])
        logger.info("Successfully retrieved database credentials from Secrets Manager")
        return creds
    except Exception as e:
        logger.error("Failed to retrieve secret from Secrets Manager: %s", str(e))
        raise

def get_conn():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    db = c.get("dbname", "labdb")
    
    try:
        conn = pymysql.connect(
            host=host, user=user, password=password,
            port=port, database=db, autocommit=True
        )
        logger.info("Successfully connected to RDS database")
        return conn
    except Exception as e:
        logger.error("Database connection failed: %s", str(e))
        raise

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h2>EC2 → RDS Notes App</h2>
    <p>POST /add?note=hello</p>
    <p>GET /list</p>
    """

@app.route("/init")
def init_db():
    try:
        c = get_db_creds()
        host = c["host"]
        user = c["username"]
        password = c["password"]
        port = int(c.get("port", 3306))

        conn = pymysql.connect(host=host, user=user, password=password, port=port, autocommit=True)
        cur = conn.cursor()
        cur.execute("CREATE DATABASE IF NOT EXISTS labdb;")
        cur.execute("USE labdb;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                note VARCHAR(255) NOT NULL
            );
        """)
        cur.close()
        conn.close()
        logger.info("Database initialized successfully")
        return "Initialized labdb + notes table."
    except Exception as e:
        logger.error("Database initialization failed: %s", str(e))
        return f"Error during initialization: {str(e)}", 500

@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        logger.warning("Add request received without note parameter")
        return "Missing note param. Try: /add?note=hello", 400
    
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
        cur.close()
        conn.close()
        logger.info("Note added successfully: %s", note)
        return f"Inserted note: {note}"
    except Exception as e:
        logger.error("Failed to add note: %s", str(e))
        return f"Error adding note: {str(e)}", 500

@app.route("/list")
def list_notes():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        
        out = "<h3>Notes</h3><ul>"
        for r in rows:
            out += f"<li>{r[0]}: {r[1]}</li>"
        out += "</ul>"
        logger.info("Successfully retrieved %d notes", len(rows))
        return out
    except Exception as e:
        logger.error("Failed to list notes: %s", str(e))
        return f"Error listing notes: {str(e)}", 500

if __name__ == "__main__":
    logger.info("Starting Flask application on port 80")
    app.run(host="0.0.0.0", port=80)
PY

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=AWS_REGION=us-east-2
Environment=SECRET_ID=lab-rds-mysql-v1
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp
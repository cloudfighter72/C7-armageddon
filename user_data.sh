#!/bin/bash
dnf update -y
dnf install -y python3-pip
pip3 install flask pymysql boto3 watchtower

mkdir -p /opt/rdsapp

cat >/opt/rdsapp/app.py <<'PY'
import json, os, time, logging, boto3, pymysql
from flask import Flask, request
import watchtower

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# CloudWatch setup 
REGION = os.environ.get("AWS_REGION", "us-east-2")
SECRET_ID = os.environ.get("SECRET_ID")

cloudwatch_handler = watchtower.CloudWatchLogHandler(
    log_group_name="/aws/ec2/${name_prefix}-rds-app",
    send_interval=10,
    boto3_client=boto3.client('logs', region_name=REGION)
)
logger.addHandler(cloudwatch_handler)

secrets_client = boto3.client("secretsmanager", region_name=REGION)

def get_db_creds():
    try:
        resp = secrets_client.get_secret_value(SecretId=SECRET_ID)
        return json.loads(resp["SecretString"])
    except Exception as e:
        logger.error(f"Secrets retrieval failed: {{e}}")
        raise

def get_conn():
    c = get_db_creds()
    return pymysql.connect(
        host=c["host"], 
        user=c["username"], 
        password=c["password"], 
        port=int(c.get("port", 3306)), 
        database=c.get("dbname", "labdb"), 
        autocommit=True
    )

app = Flask(__name__)

@app.route("/")
def home():
    return "<h2>EC2 to RDS App: Success!</h2><p>Try /init then /add?note=hello</p>"

@app.route("/init")
def init_db():
    try:
        c = get_db_creds()
        dbname = c.get("dbname", "rds_db") # Use the name from the secret
        conn = pymysql.connect(host=c["host"], user=c["username"], password=c["password"], port=int(c.get("port", 3306)), autocommit=True)
        cur = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {dbname};")
        cur.execute(f"USE {dbname};")
        cur.execute("CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(255) NOT NULL);")
        cur.close()
        conn.close()
        return f"Initialized {dbname} successfully."
    except Exception as e:
        return f"Init failed: {str(e)}", 500

@app.route("/add")
def add_note():
    note = request.args.get("note", "Empty note")
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close()
    conn.close()
    return f"Added note: {note}"

@app.route("/list")
def list_notes():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        html = "<h2>Stored Notes</h2><ul>"
        for row in rows:
            html += f"<li><b>ID {row[0]}:</b> {row[1]}</li>"
        html += "</ul><a href='/'>Back Home</a>"
        
        return html
    except Exception as e:
        return f"List failed: {str(e)}", 500
PY

cat >/etc/systemd/system/rdsapp.service <<SERVICE
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=AWS_REGION=${region}
Environment=SECRET_ID=${name_prefix}/rds/db_secrets08
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp
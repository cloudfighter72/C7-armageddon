#!/bin/bash
# Rendered by Terraform via templatefile().
# Template variables: region, secret_id
# A literal dollar-brace in this file must be escaped as $${...}
set -euxo pipefail

exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

APP_DIR=/opt/rdsapp

dnf update -y

# python3-pip for the venv bootstrap. mariadb105 provides the `mysql`
# command line client that section 6.7 asks you to install by hand; it is
# preinstalled here so the check works immediately. On Amazon Linux 2023
# the package is mariadb105, not mysql.
dnf install -y python3 python3-pip mariadb105

mkdir -p "$APP_DIR"

# AL2023 ships an externally managed Python. A virtualenv avoids pip's
# PEP 668 refusal and keeps app dependencies away from system tooling.
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install \
  "flask>=3.0,<4" \
  "gunicorn>=21.2" \
  "pymysql>=1.1" \
  "boto3>=1.34"

cat >"$APP_DIR/app.py" <<'PY'
"""Notes app. Credentials come from Secrets Manager via the instance role."""

import json
import logging
import os
import time

import boto3
import pymysql
from flask import Flask, request
from markupsafe import escape

REGION = os.environ.get("AWS_REGION", "us-east-2")
SECRET_ID = os.environ["SECRET_ID"]

CREDS_TTL_SECONDS = 300
SECRET_MAX_ATTEMPTS = 6

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("rdsapp")

# No static keys anywhere. boto3 picks up the instance role from IMDS.
session = boto3.session.Session(region_name=REGION)
secrets = session.client("secretsmanager")

app = Flask(__name__)

_creds_cache = {"value": None, "fetched_at": 0.0}


def get_db_creds():
    """Fetch and cache the secret, retrying while the instance warms up."""
    now = time.time()
    cached = _creds_cache["value"]
    if cached and (now - _creds_cache["fetched_at"]) < CREDS_TTL_SECONDS:
        return cached

    last_error = None
    for attempt in range(1, SECRET_MAX_ATTEMPTS + 1):
        try:
            response = secrets.get_secret_value(SecretId=SECRET_ID)
            creds = json.loads(response["SecretString"])
            _creds_cache["value"] = creds
            _creds_cache["fetched_at"] = time.time()
            return creds
        except Exception as exc:
            last_error = exc
            logger.warning("Secret fetch attempt %s failed: %s", attempt, exc)
            time.sleep(min(30, 5 * attempt))

    raise RuntimeError("Could not read secret " + SECRET_ID) from last_error


def get_conn(database=""):
    """Open a connection. Pass database=None for no default database."""
    creds = get_db_creds()
    target = creds.get("dbname") if database == "" else database
    return pymysql.connect(
        host=creds["host"],
        user=creds["username"],
        password=creds["password"],
        port=int(creds.get("port", 3306)),
        database=target,
        connect_timeout=5,
        read_timeout=10,
        write_timeout=10,
        autocommit=True,
    )


@app.get("/")
def home():
    return (
        "<h2>EC2 to RDS App</h2>"
        "<p><a href='/health'>/health</a> proves the host can reach RDS.</p>"
        "<p>Then <a href='/init'>/init</a>, then <code>/add?note=hello</code>, "
        "then <a href='/list'>/list</a>.</p>"
    )


@app.get("/health")
def health():
    try:
        conn = get_conn()
        with conn.cursor() as cur:
            cur.execute("SELECT 1;")
        conn.close()
        return {"status": "ok"}, 200
    except Exception as exc:
        logger.exception("Health check failed")
        return {"status": "error", "detail": str(exc)}, 500


@app.get("/init")
def init_db():
    try:
        creds = get_db_creds()
        dbname = creds.get("dbname", "labdb")
        conn = get_conn(database=None)
        with conn.cursor() as cur:
            cur.execute("CREATE DATABASE IF NOT EXISTS `" + dbname + "`;")
            cur.execute("USE `" + dbname + "`;")
            cur.execute(
                "CREATE TABLE IF NOT EXISTS notes ("
                "id INT AUTO_INCREMENT PRIMARY KEY, "
                "note VARCHAR(255) NOT NULL, "
                "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
            )
        conn.close()
        logger.info("Initialised database %s", dbname)
        return "Initialised " + dbname + " successfully."
    except Exception as exc:
        logger.exception("Init failed")
        return "Init failed: " + str(exc), 500


@app.get("/add")
def add_note():
    note = request.args.get("note", "Empty note")
    try:
        conn = get_conn()
        with conn.cursor() as cur:
            cur.execute("INSERT INTO notes (note) VALUES (%s);", (note,))
        conn.close()
        logger.info("Added note: %s", note)
        return "Added note: " + str(escape(note))
    except Exception as exc:
        logger.exception("Add failed")
        return "Add failed: " + str(exc), 500


@app.get("/list")
def list_notes():
    try:
        conn = get_conn()
        with conn.cursor() as cur:
            cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
            rows = cur.fetchall()
        conn.close()
        items = "".join(
            "<li><b>ID {}:</b> {}</li>".format(row[0], escape(str(row[1])))
            for row in rows
        )
        return "<h2>Stored Notes</h2><ul>" + items + "</ul><a href='/'>Back Home</a>"
    except Exception as exc:
        logger.exception("List failed")
        return "List failed: " + str(exc), 500


if __name__ == "__main__":
    # Manual debugging only. Systemd runs gunicorn on port 80.
    app.run(host="0.0.0.0", port=8080)
PY

# Terraform substitutes into this heredoc before bash ever sees it.
# Only the secret's NAME is written to disk, never the credentials.
cat >/etc/rdsapp.env <<'ENV'
AWS_REGION=${region}
AWS_DEFAULT_REGION=${region}
SECRET_ID=${secret_id}
PYTHONUNBUFFERED=1
ENV

chmod 0644 /etc/rdsapp.env

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/rdsapp
EnvironmentFile=/etc/rdsapp.env
ExecStart=/opt/rdsapp/venv/bin/gunicorn \
  --workers 2 \
  --threads 4 \
  --timeout 30 \
  --bind 0.0.0.0:80 \
  --access-logfile - \
  --error-logfile - \
  app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now rdsapp
systemctl --no-pager status rdsapp || true
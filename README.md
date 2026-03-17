# Lab 1c — RDS Credential Drift Detection & Remediation

## PART I — Application Endpoints (Test from your local machine/browser)

### Replace <PUBLIC_IP> with your actual EC2 public IP

```plaintext
http://56.125.168.137/init
http://56.125.168.137/add?note=first_note
http://56.125.168.137/add?note=blue_book_gentlemen
http://56.125.168.137/add?note=brazil_colombia_capeverde
http://56.125.168.137/add?note=this_is_200k_work
http://56.125.168.137/add?note=lab_1b_is_a_success
http://56.125.168.137/list
```

---

## PART II — Configuration Validation (run on EC2 instance)

### 2.1 Retrieve database connection parameters from Parameter Store

```bash
aws ssm get-parameters \
  --names "/lab/db/endpoint" "/lab/db/port" "/lab/db/name" \
  --with-decryption \
  --region us-east-2 \
  --output table
```

### 2.2 Retrieve full database credentials from Secrets Manager (clean JSON output)

```bash
aws secretsmanager get-secret-value \
  --secret-id "lab/rds/mysql_v17" \
  --region us-east-2 \
  --query SecretString \
  --output json | jq .
  ```

---

## PART III — Monitoring & Alerting (SNS + CloudWatch)

### 3.1 Subscribe email to SNS topic (only needed once)

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-2:185196963048:lab-1c-db-incidents-v1 \
  --protocol email \
  --notification-endpoint bjett2000@hotmail.com \
  --region us-east-2
```

### 3.2 Verify subscription status (after confirming email link)

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-2:185196963048:lab-1c-db-incidents-v1 \
  --region us-east-2 \
  --query "Subscriptions[?Protocol=='email'].{Endpoint:Endpoint, Status:Status}" \
  --output table
```

---

## PART IV - Simulate the Incident (Trigger the Alarm)

Purpose: Force a connection failure to generate logs, increment the metric, and trigger the alarm.
Step 4.1 — Change the RDS password (most reliable way to trigger credential failure)

Go to AWS Console → RDS → select your instance (lab-1c-mysql)
Actions → Modify
Under "Settings" → change the Master password to something different from what's in Secrets Manager
Apply immediately (no maintenance window needed)

```plaintext
http://56.125.168.137/init
http://56.125.168.137/add?note=test-failure
http://56.125.168.137/list
```

---

## PART V — Incident Runbook (execute in exact order)

### 5.1 Acknowledge – Check current alarm state

```bash
aws cloudwatch describe-alarms \
  --alarm-names lab-1c-db-connection-failure \
  --region us-east-2 \
  --query "MetricAlarms[].StateValue" \
  --output text
```

### 5.2 Observe – Check recent error logs (last 1 hour)

```bash
aws logs filter-log-events \
  --log-group-name "/aws/ec2/lab-1c-rds-app" \
  --filter-pattern '"Access denied for user"' \
  --region us-east-2 \
  --start-time "$(date -d '-1 hour' +%s000)" \
  --limit 10 \
  --output json \
| jq -r '.events[] | [(.timestamp / 1000 | todate), .message] | @tsv' \
| sort -n
```

### 5.3 Validate Configuration Sources (repeat from Part II if needed)

```bash
aws ssm get-parameters \
  --names "/lab/db/endpoint" "/lab/db/port" "/lab/db/name" \
  --with-decryption \
  --region us-east-2 \
  --output table

aws secretsmanager get-secret-value \
  --secret-id "lab/rds/mysql_v17" \
  --region us-east-2 \
  --query SecretString \
  --output json | jq .
```

Notice the Password in the Secrets Manager was incorrect causing credential drift.

### 5.4 Recovery – Restore RDS password to match Secrets Manager

```bash
# First Retrieve current password from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id "lab/rds/mysql_v17" \
  --region us-east-2 \
  --query SecretString \
  --output text | jq -r .password

# Then: Apply it to RDS (replace <PASTE_PASSWORD_HERE>)
aws rds modify-db-instance \
  --db-instance-identifier lab-1c-mysql \
  --master-user-password "StFWydLMdmKvZEhb" \
  --apply-immediately \
  --region us-east-2

# Monitor RDS status until 'available'
aws rds describe-db-instances \
  --db-instance-identifier lab-1c-mysql \
  --region us-east-2 \
  --query "DBInstances[].DBInstanceStatus" \
  --output text
```

### 5.5 Post-recovery verification

```plaintext
curl http://56.125.168.137/list
```

### 5.6 Confirm alarm clears (wait 5–10 minutes)

```bash
aws cloudwatch describe-alarms \
  --alarm-names lab-1c-db-connection-failure \
  --region us-east-2 \
  --query "MetricAlarms[].StateValue" \
  --output text
```

### 5.7 Confirm logs normalize (no new errors in last 5 minutes)

```bash
aws logs filter-log-events \
  --log-group-name "/aws/ec2/lab-1c-rds-app" \
  --filter-pattern '"Access denied for user"' \
  --region us-east-2 \
  --start-time "$(date -d '-5 minutes' +%s000)" \
  --output text
```

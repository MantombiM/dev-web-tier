#!/bin/bash
set -e

yum update -y

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

yum install -y python3 python3-pip

REGION=$(ec2-metadata --availability-zone | cut -d ' ' -f 2 | sed 's/[a-z]$//')

mkdir -p /opt/rewards

cat > /opt/rewards/health-service.py << 'PYEOF'
#!/usr/bin/env python3
import json, os
from http.server import HTTPServer, BaseHTTPRequestHandler

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            response = json.dumps({
                "service": "rewards",
                "status": "ok",
                "commit": "bootstrap",
                "region": os.getenv("AWS_REGION", "unknown")
            })
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(response.encode())
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    HTTPServer(('', 8080), HealthHandler).serve_forever()
PYEOF

chown ec2-user:ec2-user /opt/rewards/health-service.py
chmod 644 /opt/rewards/health-service.py

cat > /etc/systemd/system/rewards-health.service << UNITEOF
[Unit]
Description=Rewards Health Service (Bootstrap)
After=network.target

[Service]
Type=simple
User=ec2-user
Environment=AWS_REGION=$$REGION
ExecStart=/usr/bin/python3 /opt/rewards/health-service.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNITEOF

systemctl daemon-reload
systemctl enable rewards-health
systemctl start rewards-health

INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)

aws ec2 create-tags \
  --region $REGION \
  --resources $INSTANCE_ID \
  --tags Key=AnsibleManaged,Value=true

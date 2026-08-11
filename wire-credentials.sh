#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/workshop.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Copy workshop.env.example to workshop.env and fill it in." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a
NR_REGION="${NR_REGION:-US}"

for v in NR_LICENSE_KEY NR_USER_API_KEY NR_ACCOUNT_ID; do
  if [ -z "${!v:-}" ]; then echo "ERROR: $v is empty in workshop.env" >&2; exit 1; fi
done

echo "==> Wiring New Relic Infrastructure agent (metrics + process events)"
sudo tee /etc/newrelic-infra.yml >/dev/null <<EOF
license_key: ${NR_LICENSE_KEY}
display_name: workshopaqm-infra
enable_process_metrics: true
EOF

echo "==> Enabling host logs (syslog) so all signals flow from the start"
sudo mkdir -p /etc/newrelic-infra/logging.d
sudo tee /etc/newrelic-infra/logging.d/logging.yml >/dev/null <<EOF
logs:
  - name: syslog
    file: /var/log/syslog
EOF

echo "==> Wiring Node APM (newrelic.js)"
sed -i "s/license_key: '.*'/license_key: '${NR_LICENSE_KEY}'/" "${SCRIPT_DIR}/newrelic.js"

echo "==> Writing shared Terraform vars (o11yascode/terraform.tfvars)"
mkdir -p "${SCRIPT_DIR}/o11yascode"
cat > "${SCRIPT_DIR}/o11yascode/terraform.tfvars" <<EOF
account_id = "${NR_ACCOUNT_ID}"
api_key    = "${NR_USER_API_KEY}"
region     = "${NR_REGION}"
EOF

if command -v newrelic >/dev/null 2>&1; then
  echo "==> Configuring newrelic CLI profile (workshop)"
  # -y and </dev/null keep this non-interactive: without them the CLI prompts for
  # any missing value and blocks forever, since setup scripts have no stdin.
  newrelic profile add --profile workshop \
    --apiKey "${NR_USER_API_KEY}" \
    --accountId "${NR_ACCOUNT_ID}" \
    --region "${NR_REGION}" \
    --licenseKey "${NR_LICENSE_KEY}" \
    -y </dev/null || true
fi

echo "==> Restarting Infrastructure agent"
sudo systemctl restart newrelic-infra || true

echo "==> Starting the app (workshopaqm-app)"
pkill -f "node -r newrelic server.js" 2>/dev/null || true
cd "${SCRIPT_DIR}"
nohup node -r newrelic server.js > app.log 2>&1 &
echo "Done. Host 'workshopaqm-infra' and app 'workshopaqm-app' should report within a few minutes."

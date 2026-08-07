#!/bin/bash
set -uo pipefail
# Note: this only destroys the Terraform-managed configs below. The manual
# "Challenge 1 - Alert Storm" policy is created by hand in the UI and is NOT in
# any Terraform state, so it is not removed here. The ephemeral VM tears down at
# track end; delete that policy by hand if you want it gone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for d in c0-dashboard c2-automated-grouped c3-tuned-signal c4-routed-muted; do
  cfg="${SCRIPT_DIR}/${d}"
  if [ -d "${cfg}/.terraform" ] || [ -f "${cfg}/terraform.tfstate" ]; then
    echo "==> destroying ${d}"
    ( cd "${cfg}" && terraform destroy -auto-approve -var-file=../terraform.tfvars ) || true
  fi
done
echo "All applied AQM configs destroyed."

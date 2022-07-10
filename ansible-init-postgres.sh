#!/bin/bash
set -euo pipefail

# execute the playbook.
exec ansible-playbook /dev/stdin <<<"$1"

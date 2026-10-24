#!/usr/bin/env bash
# Run Terraform in one domain root.
#
#   scripts/tf.sh daveklein.com public init
#   scripts/tf.sh daveklein.com public plan
#   scripts/tf.sh soinkleined.com private apply
#
# State key is domains/<domain>/<public|private>/terraform.tfstate.
# backend.hcl at the repo root holds the bucket, region, and lockfile flag.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -lt 3 ]]; then
  echo "usage: scripts/tf.sh <domain> <public|private> <terraform arguments...>" >&2
  echo "example: scripts/tf.sh daveklein.com public init" >&2
  exit 64
fi

domain="$1"
scope="$2"
shift 2

case "${scope}" in
  public|private) ;;
  *)
    echo "scope must be public or private, got: ${scope}" >&2
    exit 64
    ;;
esac

dir="${root}/domains/${domain}/${scope}"
if [[ ! -d "${dir}" ]]; then
  echo "no Terraform root at domains/${domain}/${scope}" >&2
  exit 66
fi

key="domains/${domain}/${scope}/terraform.tfstate"

# Tests do not need the state bucket. Install modules and providers locally
# on a fresh checkout, then leave an already-initialised backend alone.
if [[ "${1}" == "test" && ! -d "${dir}/.terraform" ]]; then
  terraform -chdir="${dir}" init -backend=false -input=false
fi

if [[ "${1}" == "init" ]]; then
  if [[ ! -f "${root}/backend.hcl" ]]; then
    echo "missing ${root}/backend.hcl (copy backend.hcl.example and set the bucket)" >&2
    exit 66
  fi
  shift
  exec terraform -chdir="${dir}" init \
    -backend-config="${root}/backend.hcl" \
    -backend-config="key=${key}" \
    "$@"
fi

exec terraform -chdir="${dir}" "$@"

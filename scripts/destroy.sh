#!/bin/bash

set -euo pipefail

# Colors
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Arguments
ENV="${1:-dev}"
MODE="${2:-for_retries}"
VAR_FILE="../environments/${ENV}/terraform.tfvars"
TF_WORK_DIR="../main"

# Help message
echo -e "${CYAN}Terraform Destroy Helper Script${RESET}"
echo -e "${YELLOW}Environment (arg #1):${RESET} ${GREEN}${ENV}${RESET}  (options: 'dev' [default], 'staging', 'prod')"
echo -e "${YELLOW}Mode (arg #2):       ${RESET} ${GREEN}${MODE}${RESET}  (options: 'for_retries' [default], 'all')"
echo -e "${YELLOW}Using variable file:${RESET} ${VAR_FILE}"
echo -e "${YELLOW}Terraform working directory:${RESET} ${TF_WORK_DIR}"
echo

# Validate variable file
if [[ ! -f "$VAR_FILE" ]]; then
  echo -e "${RED}ERROR:${RESET} Variable file '${VAR_FILE}' not found!"
  exit 1
fi

if [[ "$MODE" == "all" ]]; then
  terraform -chdir="$TF_WORK_DIR" destroy -var-file="$VAR_FILE" -auto-approve

elif [[ "$MODE" == "for_retries" ]]; then
  echo -e "${CYAN}Building target list (excluding NAT and dependencies)...${RESET}"

  EXCLUDE_PATTERNS=(
    'module.vpc_network.aws_nat_gateway.this\[0\]'
    'module.vpc_network.aws_eip.nat\[0\]'
    'module.vpc_network.aws_subnet.public\[0\]'
    'module.vpc_network.aws_route_table.public'
    'module.vpc_network.aws_route_table_association.public_subnets\[0\]'
    'module.vpc_network.aws_internet_gateway.igw'
    'module.vpc_network.aws_vpc.main'
    'data.aws_availability_zones.available'
  )

  GREP_EXCLUDE=$(printf "|%s" "${EXCLUDE_PATTERNS[@]}")
  GREP_EXCLUDE="${GREP_EXCLUDE:1}" # strip leading |

  TARGETS=$(terraform -chdir="$TF_WORK_DIR" state list | \
    grep -Ev "$GREP_EXCLUDE" | \
    sed 's/^/-target=/')

  if [[ -z "$TARGETS" ]]; then
    echo -e "${YELLOW}No targets found to destroy.${RESET}"
    exit 0
  fi

  echo -e "${CYAN}Destroying with targets:${RESET}"
  echo "$TARGETS"
  echo -e "${YELLOW}Exclude regex:${RESET} $GREP_EXCLUDE"
  echo -e "${YELLOW}Filtered state list:${RESET}"

  # shellcheck disable=SC2086
  terraform -chdir="$TF_WORK_DIR" destroy -var-file="$VAR_FILE" -auto-approve $TARGETS

else
  echo -e "${RED}Invalid mode: ${MODE}${RESET}"
  echo "Usage: $0 [env=dev|prod|staging] [mode=all|for_retries]"
  exit 1
fi
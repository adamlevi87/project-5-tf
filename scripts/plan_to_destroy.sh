#!/bin/bash

set -euo pipefail

# Colors
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# Arguments
ENV="${1:-dev}"
MODE="${2:-for_retries}"
VAR_FILE="../environments/${ENV}/terraform.tfvars"
TF_WORK_DIR="../main"

# Help message
echo -e "${CYAN}Terraform Destroy PLAN Script${RESET}"
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
  terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE"

elif [[ "$MODE" == "for_retries" ]]; then
  echo -e "${CYAN}Building target list (excluding NAT and dependencies)...${RESET}"

EXCLUDE_PATTERNS=(
  'module.vpc_network.aws_nat_gateway.this\[[^]]+\]'
  'module.vpc_network.aws_eip.nat\[[^]]+\]'
  'module.vpc_network.aws_subnet.public\[[^]]+\]'
  'module.vpc_network.aws_route_table.public'
  'module.vpc_network.aws_route_table_association.public_subnets\[[^]]+\]'
  'module.vpc_network.aws_internet_gateway.igw'
  'module.vpc_network.aws_vpc.main'
  'data.aws_availability_zones.available'
)


# Properly join the patterns into a single grep-safe regex
GREP_EXCLUDE=$(IFS="|"; echo "${EXCLUDE_PATTERNS[*]}")

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

  for TARGET in $TARGETS; do
    echo -e "\n${GREEN}======== PLAN DESTROY FOR: ${TARGET} ========${RESET}"
    terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE" "$TARGET"

    echo
    read -rp "Continue to next target? [Y/n]: " answer
    case "$answer" in
      [nN][oO]|[nN])
        echo -e "${YELLOW}Aborting per user request.${RESET}"
        exit 0
        ;;
    esac
  done

else
  echo -e "${RED}Invalid mode: ${MODE}${RESET}"
  echo "Usage: $0 [env=dev|prod|staging] [mode=all|for_retries]"
  exit 1
fi

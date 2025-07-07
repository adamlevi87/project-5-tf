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
NAT_MODE="${3:-single}"
STRATEGY="${4:-separate}"
VAR_FILE="../environments/${ENV}/terraform.tfvars"
TF_WORK_DIR="../main"

# Help option
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo -e "${CYAN}Terraform Destroy PLAN Script - Help${RESET}"
  echo
  echo -e "${YELLOW}Usage:${RESET} $0 [env] [mode] [nat_mode] [strategy]"
  echo
  echo -e "${YELLOW}Arguments:${RESET}"
  echo -e "  ${GREEN}1. env        ${RESET}→ Environment to target.         Default: ${CYAN}dev${RESET}"
  echo -e "                 Options: ${CYAN}dev${RESET}, ${CYAN}staging${RESET}, ${CYAN}prod${RESET}"
  echo -e "  ${GREEN}2. mode       ${RESET}→ Destroy mode.                 Default: ${CYAN}for_retries${RESET}"
  echo -e "                 Options: ${CYAN}for_retries${RESET}, ${CYAN}all${RESET}"
  echo -e "  ${GREEN}3. nat_mode   ${RESET}→ NAT Gateway mode.             Default: ${CYAN}single${RESET}"
  echo -e "                 Options: ${CYAN}single${RESET}, ${CYAN}real${RESET}"
  echo -e "  ${GREEN}4. strategy   ${RESET}→ Plan execution strategy.      Default: ${CYAN}separate${RESET}"
  echo -e "                 Options: ${CYAN}separate${RESET} (each target), ${CYAN}together${RESET} (all targets at once)"
  echo
  echo -e "Example:"
  echo -e "  ${GREEN}$0 dev for_retries single separate${RESET}"
  echo
  exit 0
fi


# Help message
echo -e "${CYAN}Terraform Destroy PLAN Script${RESET}"
echo -e "${YELLOW}Environment (arg #1):${RESET} ${GREEN}${ENV}${RESET}   (options: 'dev' [default], 'staging', 'prod')"
echo -e "${YELLOW}Mode (arg #2):       ${RESET} ${GREEN}${MODE}${RESET}  (options: 'for_retries' [default], 'all')"
echo -e "${YELLOW}NAT Mode (arg #3):   ${RESET} ${GREEN}${NAT_MODE}${RESET}  (options: 'single' [default], 'real')"
echo -e "${YELLOW}Strategy (arg #4):   ${RESET} ${GREEN}${STRATEGY}${RESET}  (options: 'separate' [default], 'together')"
echo -e "${YELLOW}Using variable file:${RESET} ${VAR_FILE}"
echo -e "${YELLOW}Terraform working directory:${RESET} ${TF_WORK_DIR}"
echo

# Validate NAT mode
if [[ "$NAT_MODE" != "single" && "$NAT_MODE" != "real" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid NAT mode '${NAT_MODE}'. Use 'single' or 'real'."
  exit 1
fi

# Validate Strategy
if [[ "$STRATEGY" != "separate" && "$STRATEGY" != "together" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid strategy '${STRATEGY}'. Use 'separate' or 'together'."
  exit 1
fi

# Validate variable file
if [[ ! -f "$VAR_FILE" ]]; then
  echo -e "${RED}ERROR:${RESET} Variable file '${VAR_FILE}' not found!"
  exit 1
fi

if [[ "$MODE" == "all" ]]; then
  terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE"

elif [[ "$MODE" == "for_retries" ]]; then
  echo -e "${CYAN}Building target list based on NAT mode '${NAT_MODE}'...${RESET}"

  if [[ "$NAT_MODE" == "real" ]]; then
    # Exclude ALL NATs + ALL public subnets + their route table associations
    EXCLUDE_PATTERNS=(
      'data.aws_availability_zones.available'
      'module.vpc_network.aws_internet_gateway.igw'
      'module.vpc_network.aws_subnet.public_primary[0]'
      'module.vpc_network.aws_route_table.public_primary[0]'
      'module.vpc_network.aws_route_table_association.public_primary[0]'
      'module.vpc_network.aws_eip.nat_primary[0]'
      'module.vpc_network.aws_nat_gateway.nat_primary[0]'
      'module.vpc_network.aws_subnet.public_additional\[[^]]+\]'
      'module.vpc_network.aws_route_table.public_additional\[[^]]+\]'
      'module.vpc_network.aws_route_table_association.public_additional\[[^]]+\]'
      'module.vpc_network.aws_eip.nat_additional\[[^]]+\]'
      'module.vpc_network.aws_nat_gateway.nat_additional\[[^]]+\]'
      'module.vpc_network.aws_vpc.main'
    )

  elif [[ "$NAT_MODE" == "single" ]]; then
    # Detect which AZ the single NAT is in
    NAT_AZ=$(terraform -chdir="$TF_WORK_DIR" state list | \
      grep 'module.vpc_network.aws_nat_gateway.nat' | \
      sed -E 's/.*\["([^"]+)"\]/\1/')

    if [[ -z "$NAT_AZ" ]]; then
      echo -e "${RED}ERROR:${RESET} No NAT Gateway found in state."
      exit 1
    fi

    echo -e "${YELLOW}Single NAT detected in AZ:${RESET} $NAT_AZ"

    EXCLUDE_PATTERNS=(
      'data.aws_availability_zones.available'
      'module.vpc_network.aws_internet_gateway.igw'
      'module.vpc_network.aws_subnet.public_primary[0]'
      'module.vpc_network.aws_route_table.public_primary[0]'
      'module.vpc_network.aws_route_table_association.public_primary[0]'
      'module.vpc_network.aws_eip.nat_primary[0]'
      'module.vpc_network.aws_nat_gateway.nat_primary[0]'
      'module.vpc_network.aws_vpc.main'
    )
  fi

  # Build grep pattern
  GREP_EXCLUDE=$(IFS="|"; echo "${EXCLUDE_PATTERNS[*]}")

  echo -e "${YELLOW}Exclude regex:${RESET} $GREP_EXCLUDE"
  echo -e "${YELLOW}Remaining state entries after exclusion:${RESET}"
  terraform -chdir="$TF_WORK_DIR" state list | grep -Ev "$GREP_EXCLUDE"

  TARGETS=$(terraform -chdir="$TF_WORK_DIR" state list | \
    grep -Ev "$GREP_EXCLUDE" | \
    sed 's/^/-target=/')

  if [[ -z "$TARGETS" ]]; then
    echo -e "${YELLOW}No targets found to destroy.${RESET}"
    exit 0
  fi

  echo -e "${CYAN}Destroying with targets:${RESET}"
  echo "$TARGETS"

  if [[ "$STRATEGY" == "together" ]]; then
    echo -e "\n${GREEN}======== PLAN DESTROY (all targets together) ========${RESET}"
    # shellcheck disable=SC2086
    terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE" $TARGETS
  else
    for TARGET in $TARGETS; do
      echo -e "\n${GREEN}======== PLAN DESTROY FOR: ${TARGET} ========${RESET}"
      terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE" "$TARGET"

      echo
      read -rp "Continue to next target? [Y/n]: " answer
      case "$answer" in
        [yY][eE][sS]|[yY])
          ;;
        *) # Anything else, including empty input
          echo -e "${YELLOW}Aborting per user request.${RESET}"
          exit 0
          ;;
      esac
    done
  fi


else
  echo -e "${RED}Invalid mode: ${MODE}${RESET}"
  echo "Usage: $0 [env=dev|prod|staging] [mode=all|for_retries] [nat_mode=single|real]"
  exit 1
fi

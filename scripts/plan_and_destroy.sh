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
RUN_MODE="${2:-plan}"
SELECTION_METHOD="${3:-filter}"
NAT_MODE="${4:-single}"
DEBUG="${5:-normal}"

# Handle dash as "use default"
[[ "$ENV" == "-" ]] && ENV="dev"
[[ "$RUN_MODE" == "-" ]] && RUN_MODE="plan"
[[ "$SELECTION_METHOD" == "-" ]] && SELECTION_METHOD="filter"
[[ "$NAT_MODE" == "-" ]] && NAT_MODE="single"
[[ "$DEBUG" == "-" ]] && DEBUG="normal"

VAR_FILE="../environments/${ENV}/terraform.tfvars"
TF_WORK_DIR="../main"

show_help() {
  echo -e "${CYAN}Terraform Destroy PLAN Script - Help${RESET}"
  echo
  echo -e "${YELLOW}Usage:${RESET} $0 [env] [run_mode] [selection_method] [nat_mode] [debug]"
  echo -e "${YELLOW}Use '-' to hit the defaults ${RESET}"
  echo
  echo -e "${YELLOW}Arguments:${RESET}"
  echo -e "  ${GREEN}1. env        ${RESET}→ Environment to target.         Default: ${CYAN}dev${RESET}"
  echo -e "                 Options: ${CYAN}dev${RESET}, ${CYAN}staging${RESET}, ${CYAN}prod${RESET}"
  echo -e "  ${GREEN}2. run_mode   ${RESET}→ terraform plan -destroy or terraform destroy.      Default: ${CYAN}plan${RESET}"
  echo -e "                 Options: ${CYAN}plan${RESET},${CYAN}destroy${RESET}"
  echo -e "  ${GREEN}3. selection_method       ${RESET}→ selection method.                 Default: ${CYAN}filter${RESET}"
  echo -e "                 Options: ${CYAN}filter${RESET}, ${CYAN}all${RESET}"
  echo -e "  ${GREEN}4. nat_mode   ${RESET}→ NAT Gateway mode. How many NATs, a single one or per AZ.             Default: ${CYAN}single${RESET}"
  echo -e "                 Options: ${CYAN}single${RESET}, ${CYAN}real${RESET}"
  echo -e "  ${GREEN}5. debug   ${RESET}→ Debug mode, used with run_mode:plan & selection_method: filter to iterate over the filtered terraform resource list one by one       Default: ${CYAN}normal${RESET}"
  echo -e "                 Options: ${CYAN}debug${RESET} (each target), ${CYAN}normal${RESET} (all targets at once)"
  echo
  echo -e "Example:"
  echo -e "  ${GREEN}$0 dev plan filter single normal${RESET}"
  echo -e "Example 2:"
  echo -e "  ${GREEN}$0 dev destroy all real debug${RESET}"
  echo
}
# Help option
if [[ "$ENV" == "--help" || "$ENV" == "-h" ]]; then
  show_help
  exit 0
else
  show_help
  echo -e "${YELLOW}Running:${RESET} ${GREEN}$0 $ENV $RUN_MODE $SELECTION_METHOD $NAT_MODE $DEBUG${RESET}"
  echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${RESET}"
  read -r
fi

# Validate ENV
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid ENV'${ENV}'. Use 'dev' or 'staging' or 'prod'."
  exit 1
fi

# Validate RUN_MODE
if [[ "$RUN_MODE" != "plan" && "$RUN_MODE" != "destroy" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid RUN_MODE'${RUN_MODE}'. Use 'plan' or 'destroy'."
  exit 1
fi

# Validate SELECTION_METHOD
if [[ "$SELECTION_METHOD" != "filter" && "$SELECTION_METHOD" != "all" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid SELECTION_METHOD'${SELECTION_METHOD}'. Use 'filter' or 'all'."
  exit 1
fi

# Validate NAT mode
if [[ "$NAT_MODE" != "single" && "$NAT_MODE" != "real" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid NAT mode '${NAT_MODE}'. Use 'single' or 'real'."
  exit 1
fi

# Validate Debug
if [[ "$DEBUG" != "debug" && "$DEBUG" != "normal" ]]; then
  echo -e "${RED}ERROR:${RESET} Invalid Debug '${DEBUG}'. Use 'debug' or 'normal'."
  exit 1
fi

# Validate variable file
if [[ ! -f "$VAR_FILE" ]]; then
  echo -e "${RED}ERROR:${RESET} Variable file '${VAR_FILE}' not found!"
  exit 1
fi

# Validate RUN_MODE
if [[ "$RUN_MODE" == "plan" ]]; then
  COMMAND_RUN_MODE="plan -destroy"
elif [[ "$RUN_MODE" == "destroy"  ]]; then
  COMMAND_RUN_MODE="destroy -auto-approve"
fi

################ Script starts here ################

if [[ "$SELECTION_METHOD" == "all" ]]; then
  terraform -chdir="$TF_WORK_DIR" $COMMAND_RUN_MODE -var-file="$VAR_FILE"

elif [[ "$SELECTION_METHOD" == "filter" ]]; then

  echo -e "${CYAN}Building target list based on NAT mode '${NAT_MODE}'...${RESET}"
  # Base exclude patterns (common to both single and real modes)
  BASE_EXCLUDE_PATTERNS=(
    'data.aws_availability_zones.available'
    'module.vpc_network.aws_internet_gateway.igw'
    'module.vpc_network.aws_subnet.public_primary\[[^]]+\]'
    'module.vpc_network.aws_route_table.public_primary\[[^]]+\]'
    'module.vpc_network.aws_route_table_association.public_primary\[[^]]+\]'
    'module.vpc_network.aws_eip.nat_primary\[0\]'
    'module.vpc_network.aws_nat_gateway.nat_primary\[0\]'
    'module.vpc_network.aws_vpc.main'
    # RDS patterns (slow to create)
    'module.rds.aws_db_instance.main'
    'module.rds.aws_db_subnet_group.main'
    'module.secrets.aws_secretsmanager_secret.secrets\[\"rds-password\"\]'
    'module.secrets.aws_secretsmanager_secret_version.secrets\[\"rds-password\"\]'
  )

  # Additional patterns for real mode only
  REAL_MODE_ADDITIONAL_PATTERNS=(
    'module.vpc_network.aws_subnet.public_additional\[[^]]+\]'
    'module.vpc_network.aws_route_table.public_additional\[[^]]+\]'
    'module.vpc_network.aws_route_table_association.public_additional\[[^]]+\]'
    'module.vpc_network.aws_eip.nat_additional\[[^]]+\]'
    'module.vpc_network.aws_nat_gateway.nat_additional\[[^]]+\]'
  )

  # Check if VPC NAT gateways exist before applying mode-specific logic
  NAT_GATEWAYS=$(terraform -chdir="$TF_WORK_DIR" state list | grep 'module.vpc_network.aws_nat_gateway')
  if [[ -z "$NAT_GATEWAYS" ]]; then
    echo -e "${RED}ERROR:${RESET} No NAT Gateway found in state."
    exit 1
  fi

  if [[ "$NAT_MODE" == "real" ]]; then
    # Exclude ALL NATs + ALL public subnets + their route table associations
    EXCLUDE_PATTERNS=("${BASE_EXCLUDE_PATTERNS[@]}" "${REAL_MODE_ADDITIONAL_PATTERNS[@]}")

  elif [[ "$NAT_MODE" == "single" ]]; then
    echo -e "${YELLOW}Single NAT detected ${RESET}"

    EXCLUDE_PATTERNS=("${BASE_EXCLUDE_PATTERNS[@]}")
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

  echo -e "${CYAN}working with targets:${RESET}"
  echo "$TARGETS"

  if [[ "$DEBUG" == "normal" ]]; then
    echo -e "\n${GREEN}======== ${COMMAND_RUN_MODE} (all targets together) ========${RESET}"
    # shellcheck disable=SC2086
    terraform -chdir="$TF_WORK_DIR" $COMMAND_RUN_MODE -var-file="$VAR_FILE" $TARGETS
  elif [[ "$DEBUG" == "debug" && "$RUN_MODE" == "plan" ]]; then
    for TARGET in $TARGETS; do
      echo -e "\n${GREEN}======== PLAN DESTROY FOR: ${TARGET} ========${RESET}"
      terraform -chdir="$TF_WORK_DIR" plan -destroy -var-file="$VAR_FILE" "$TARGET" | GREP_COLOR='1;36' grep --color=always -E "rds|database|$"

      
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
  elif [[ "$DEBUG" == "debug" && "$RUN_MODE" == "destroy" ]]; then
    echo -e "\n${GREEN}========  debug and destroy - doing nothing ========${RESET}"
  fi

else
  echo "Usage: $0 [env=dev|prod|staging] [run_mode=plan|destroy] [selection_method=filter|all] [nat_mode=single|real] [debug=debug|normal]"
  exit 1
fi

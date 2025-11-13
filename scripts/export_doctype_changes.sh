#!/bin/bash

# Function to display usage information
usage() {
  cat << EOF
Usage: $0 [OPTIONS] [DOCTYPE...]

Export ERPNext doctypes to JSON files.

OPTIONS:
  -m, --module MODULE    Module name (e.g., quality_management) [REQUIRED]
  -h, --help             Display this help message and exit

ARGUMENTS:
  DOCTYPE                One or more doctype names to export [REQUIRED]

EXAMPLES:
  $0 --module quality_management -- "Job Work" "Trainee" "Training Session"
  $0 -m quality_management "Job Work" "Trainee"
  $0 -m quality_management 'Job Work' 'Trainee'

Note: Both single and double quotes work for doctype names.

EOF
}

# Initialize variables
MODULE=""
DOCTYPES=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -m|--module)
      MODULE="$2"
      shift 2
      ;;
    --)
      shift
      DOCTYPES+=("$@")
      break
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      usage
      exit 1
      ;;
    *)
      DOCTYPES+=("$1")
      shift
      ;;
  esac
done

# Validate required arguments
if [[ -z "$MODULE" ]]; then
  echo "Error: Module name is required. Use -m or --module flag." >&2
  usage
  exit 1
fi

if [[ ${#DOCTYPES[@]} -eq 0 ]]; then
  echo "Error: At least one doctype name is required." >&2
  usage
  exit 1
fi

# Get project root (assumes script is in scripts/ folder, or adjust accordingly)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Process each doctype
for d in "${DOCTYPES[@]}"; do
  folder_name=$(echo "$d" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' )
  mkdir -p "$PROJECT_ROOT/apps/erpnext/erpnext/$MODULE/doctype/$folder_name"
  cd "$PROJECT_ROOT"
  bench --site erp-next.localhost export-json "$d" "$PROJECT_ROOT/apps/erpnext/erpnext/$MODULE/doctype/$folder_name/$folder_name.json"
done

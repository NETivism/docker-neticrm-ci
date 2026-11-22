#!/bin/bash
# ==============================================================================
# netiCRM CI test runner
#
# Runs the full CI test suite inside a docker-neticrm-ci container that has
# already been initialized by /init.sh. Shared by GitHub Actions and
# Cloud Run Jobs so the test list lives in one place.
#
# Usage:
#   run-all.sh [--list] [--continue] [--only REGEX]
#     --list        print test steps and exit
#     --continue    keep running after a failed step (default: stop at first
#                   failure, later tests depend on data created by earlier ones)
#     --only REGEX  run only steps whose name matches REGEX (grep -E)
#
# Environment:
#   DRUPAL          7 or 10 (default: 7)
#   DRUPAL_ROOT     Drupal root (default: /var/www/html)
#   CI_RESULT_FILE  where to write per-step results, TSV:
#                   <status>\t<seconds>\t<name>  (default: /tmp/ci-result.tsv)
#
# Exit code: 0 all passed, 1 some step failed, 2 usage / environment error
# ==============================================================================

DRUPAL="${DRUPAL:-7}"
DRUPAL_ROOT="${DRUPAL_ROOT:-/var/www/html}"
CI_RESULT_FILE="${CI_RESULT_FILE:-/tmp/ci-result.tsv}"
# playwright.config.js switches retries/workers/forbidOnly on this
export CI="${CI:-true}"

if [ "$DRUPAL" = "7" ]; then
  MODULE_DIR="$DRUPAL_ROOT/sites/all/modules/civicrm"
else
  MODULE_DIR="$DRUPAL_ROOT/modules/civicrm"
fi
PHPUNIT_DIR="$MODULE_DIR/tests/phpunit"
PLAYWRIGHT_DIR="$MODULE_DIR/tests/playwright"

# Test steps: "<name>|<type>|<args>"
#   type phpunit    -> cd $PHPUNIT_DIR    && phpunit <args>
#   type playwright -> cd $PLAYWRIGHT_DIR && npx playwright test <args>
STEPS=(
  "Independent Unit Test - Smarty|phpunit|Packages/Smarty"
  "Unit Test - Type test|phpunit|CRM/Utils/TypeTest.php"
  "Unit Test - Contribution - Duplicate receipt id test|phpunit|--filter testLastReceiptId CRM/Contribute/BAO/ContributionTest.php"
  "Unit Test - Concurrent IPN test|phpunit|CRM/Core/Payment/BaseIPNTest.php"
  "Payment Test - ALLPAY|phpunit|CRM/Core/Payment/ALLPAYTest.php"
  "Payment Test - Neweb(new)|phpunit|CRM/Core/Payment/SPGATEWAYTest.php"
  "Payment Test - LINE Pay|phpunit|CRM/Core/Payment/LinePayTest.php"
  "Payment Test - TapPay|phpunit|CRM/Core/Payment/TapPayTest.php"
  "Payment Test - Backer|phpunit|CRM/Core/Payment/BackerTest.php"
  "API Test - Contribution Recur|phpunit|api/v3/ContributionRecurTest.php"
  "API Test - Get Options|phpunit|api/v3/GetOptionsTest.php"
  "API Test - Phone|phpunit|--group CItesting api/v3/PhoneTest.php"
  "API Test - Participant|phpunit|--group CItesting api/v3/ParticipantTest.php"
  "API Test - Activity|phpunit|--group CItesting api/v3/ActivityTest.php"
  "API Test - Membership|phpunit|--group CItesting api/v3/MembershipTest.php"
  "Frontend - Batch Actions - Playwright|playwright|tests/batch_action.spec.js"
  "Frontend - All Pages - Playwright|playwright|tests/page.spec.js"
  "Frontend - Add Contact - Playwright|playwright|tests/add_contact.spec.js"
  "Frontend - Contribution Page Editing - Playwright|playwright|tests/add_contribution_page.spec.js"
  "Frontend - Event Editing - Playwright|playwright|tests/add_event.spec.js"
  "Frontend - Edit Contact - Playwright|playwright|tests/edit_contact.spec.js"
  "Frontend - Custom Data - Playwright|playwright|tests/custom_data.spec.js"
  "Payment Test - ALLPAY - Playwright|playwright|tests/contribution_allpay.spec.js"
  "Payment Test - ALLPAY - ATM - Playwright|playwright|tests/contribution_allpay_atm.spec.js"
  "Payment Test - ALLPAY - Barcode - Playwright|playwright|tests/contribution_allpay_barcode.spec.js"
  "Payment Test - SPGATEWAY - Playwright|playwright|tests/contribution_spgateway.spec.js"
  "Frontend - Contribution Editing - Playwright|playwright|tests/new_contribution.spec.js"
  "Frontend - Advanced Search - Playwright|playwright|tests/advanced_search.spec.js"
  "Frontend - Group Editing - Playwright|playwright|tests/add_group.spec.js"
  "Frontend - Check Membership Type - Playwright|playwright|tests/check_membership.spec.js"
  "Frontend - Import Records - Playwright|playwright|tests/import.spec.js"
  "Frontend - Event Normal Registration - Playwright|playwright|tests/event_normal_register.spec.js"
  "Frontend - Event Registration for limited participants without waitlist - Playwright|playwright|tests/event_limit_nowait_register.spec.js"
  "Frontend - Event Registration for limited participants with waitlist - Playwright|playwright|tests/event_limit_wait_register.spec.js"
  "Frontend - Event Registration for limited participants required approval - Playwright|playwright|tests/event_limit_approval_register.spec.js"
  "Frontend - Event Registration for unlimited participants require approval - Playwright|playwright|tests/event_unlimit_approval_register.spec.js"
  "Frontend - Participant Editing - Playwright|playwright|tests/event_participant.spec.js"
  "Frontend - Mailing Editing - Playwright|playwright|tests/edit_mailing.spec.js"
  "Frontend - Contribution Booster - Playwright|playwright|tests/contribution_booster.spec.js"
  "Frontend - Report Page Checking - Playwright|playwright|tests/report_check.spec.js"
)

CONTINUE=0
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      for s in "${STEPS[@]}"; do echo "${s%%|*}"; done
      exit 0
      ;;
    --continue) CONTINUE=1 ;;
    --only)
      shift
      [ -z "$1" ] && { echo "--only requires a REGEX" >&2; exit 2; }
      ONLY="$1"
      ;;
    -h|--help)
      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

for d in "$PHPUNIT_DIR" "$PLAYWRIGHT_DIR"; do
  if [ ! -d "$d" ]; then
    echo "Directory not found: $d (DRUPAL=$DRUPAL, DRUPAL_ROOT=$DRUPAL_ROOT)" >&2
    exit 2
  fi
done

: > "$CI_RESULT_FILE"
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAILED_NAMES=()

ts() { date +"%Y-%m-%d %H:%M:%S %z"; }

echo "== netiCRM CI: Drupal $DRUPAL, module dir $MODULE_DIR"
echo "== started at $(ts)"

for s in "${STEPS[@]}"; do
  name="${s%%|*}"
  rest="${s#*|}"
  type="${rest%%|*}"
  args="${rest#*|}"

  if [ -n "$ONLY" ] && ! echo "$name" | grep -qE -- "$ONLY"; then
    continue
  fi
  TOTAL=$((TOTAL + 1))

  if [ "$FAILED" -gt 0 ] && [ "$CONTINUE" -eq 0 ]; then
    SKIPPED=$((SKIPPED + 1))
    printf 'skipped\t0\t%s\n' "$name" >> "$CI_RESULT_FILE"
    continue
  fi

  echo ""
  echo "---------------------------------------------------------------------"
  echo ">> [$TOTAL] $name"
  echo ">> $(ts)"
  echo "---------------------------------------------------------------------"

  start=$(date +%s)
  # $args is intentionally unquoted: it holds multiple CLI arguments
  case "$type" in
    phpunit)    (cd "$PHPUNIT_DIR" && phpunit $args) ;;
    playwright) (cd "$PLAYWRIGHT_DIR" && npx playwright test $args) ;;
    *)          echo "Unknown step type: $type" >&2; false ;;
  esac
  rc=$?
  elapsed=$(( $(date +%s) - start ))

  if [ "$rc" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    printf 'passed\t%s\t%s\n' "$elapsed" "$name" >> "$CI_RESULT_FILE"
    echo ">> PASSED: $name (${elapsed}s)"
  else
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$name")
    printf 'failed\t%s\t%s\n' "$elapsed" "$name" >> "$CI_RESULT_FILE"
    echo ">> FAILED (exit $rc): $name (${elapsed}s)"
  fi
done

echo ""
echo "====================================================================="
echo "== finished at $(ts)"
echo "== total $TOTAL, passed $PASSED, failed $FAILED, skipped $SKIPPED"
for n in "${FAILED_NAMES[@]}"; do
  echo "== failed: $n"
done
echo "====================================================================="

if [ "$TOTAL" -eq 0 ]; then
  echo "No step matched --only '$ONLY'" >&2
  exit 2
fi
[ "$FAILED" -eq 0 ]

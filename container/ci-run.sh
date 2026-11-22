#!/bin/bash
# ==============================================================================
# Cloud Run Job entrypoint: unpack netiCRM source, install, run tests.
#
# The image CMD (supervisord) is kept for local / GitHub Actions usage.
# Cloud Run Jobs run this script instead (--command=/ci-run.sh).
#
# Source code is NOT cloned here (the git server is not reachable from GCP).
# The dispatcher on the git server uploads a tarball to GCS, and the job mounts
# that bucket read-only at $SRC_DIR.
#
# Env:
#   SRC_TARBALL     tarball path relative to $SRC_DIR, e.g. <sha>/src-d10.tar.gz
#                   (contains a top-level "civicrm/" directory). When empty,
#                   use code already at $REPO_PATH (local debugging).
#   SRC_DIR         GCS volume mount path (default: /mnt/src)
#   DRUPAL          7 or 10 (default: 7)
#   REPO_PATH       code path (default: /mnt/neticrm-$DRUPAL/civicrm)
#   GIT_SHA         commit being tested, only used for report paths / logs
#   GIT_REF         ref being tested, only used for logs
#   STATUS_CONTEXT  name of this test variant, e.g. cloudrun/test8-d10
#   REPORT_BUCKET   GCS bucket for result.tsv / log / playwright report
#   RUN_ONLY        run only steps matching this regex (run-all.sh --only),
#                   may contain spaces, e.g. "Smarty|Type test"
#   RUN_ALL_ARGS    extra args for run-all.sh, e.g. "--continue" (split on spaces)
#   INIT_TIMEOUT    seconds allowed for /init.sh (default: 900)
#   SETTINGS_TIMEOUT abort if settings.php is still missing after this (default: 180)
#
# Exit code: 0 tests passed, 1 tests failed, 3 source missing,
#            4 install failed
# ==============================================================================

set -u -o pipefail

DRUPAL="${DRUPAL:-7}"
export DRUPAL
export DRUPAL_ROOT="${DRUPAL_ROOT:-/var/www/html}"
export RUNPORT="${RUNPORT:-8080}"
export TZ="${TZ:-Asia/Taipei}"
REPO_PATH="${REPO_PATH:-/mnt/neticrm-$DRUPAL/civicrm}"
SRC_DIR="${SRC_DIR:-/mnt/src}"
SRC_TARBALL="${SRC_TARBALL:-}"
GIT_SHA="${GIT_SHA:-}"
GIT_REF="${GIT_REF:-}"
REPORT_BUCKET="${REPORT_BUCKET:-}"
RUN_ALL_ARGS="${RUN_ALL_ARGS:-}"
RUN_ONLY="${RUN_ONLY:-}"
INIT_TIMEOUT="${INIT_TIMEOUT:-900}"
SETTINGS_TIMEOUT="${SETTINGS_TIMEOUT:-180}"
PHPVER="$(php -r 'echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;' 2>/dev/null)"
STATUS_CONTEXT="${STATUS_CONTEXT:-cloudrun/php${PHPVER}-d${DRUPAL}}"
EXECUTION="${CLOUD_RUN_EXECUTION:-local-$(date +%Y%m%d%H%M%S)}"
RESULT_FILE=/tmp/ci-result.tsv
LOG_FILE=/tmp/ci-run.log
METADATA=http://metadata.google.internal/computeMetadata/v1

# keep a copy of all output for upload, still stream to stdout (Cloud Logging)
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[ci-run $(date +'%H:%M:%S')] $*"; }

# ------------------------------------------------------------------------------
# upload artifacts to GCS via metadata-server token (no gcloud in image)
# object layout: <sha>/<context>/<execution>/{result.tsv,ci-run.log,playwright-report.tar.gz}
# ------------------------------------------------------------------------------
md() { curl -sf -m 2 -H 'Metadata-Flavor: Google' "$METADATA/$1" 2>/dev/null; }

gcs_upload() { # local-file object-name content-type
  local token code
  token="$(md instance/service-accounts/default/token | sed -E 's/.*"access_token":"([^"]+)".*/\1/')"
  [ -n "$token" ] || { log "no metadata token, skip upload $2"; return 0; }
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 300 -X POST \
    -H "Authorization: Bearer $token" -H "Content-Type: $3" \
    --data-binary @"$1" \
    "https://storage.googleapis.com/upload/storage/v1/b/${REPORT_BUCKET}/o?uploadType=media&name=$2")
  log "upload gs://${REPORT_BUCKET}/$2 -> HTTP $code"
}

upload_artifacts() {
  [ -n "$REPORT_BUCKET" ] || return 0
  local prefix="${GIT_SHA:-nosha}/${STATUS_CONTEXT//\//_}/${EXECUTION}"
  local report="$REPO_PATH/tests/playwright/playwright-report"
  if [ -d "$report" ]; then
    tar -czf /tmp/playwright-report.tar.gz -C "$(dirname "$report")" playwright-report \
      && gcs_upload /tmp/playwright-report.tar.gz "$prefix/playwright-report.tar.gz" application/gzip
  fi
  gcs_upload "$LOG_FILE" "$prefix/ci-run.log" text/plain
  # result.tsv last: the dispatcher treats its presence as "artifacts complete"
  [ -f "$RESULT_FILE" ] || printf 'error\t0\t%s\n' "$1" > "$RESULT_FILE"
  gcs_upload "$RESULT_FILE" "$prefix/result.tsv" text/tab-separated-values
}

finish() { # exit-code message
  log "$2 (exit $1)"
  if [ "$1" -ge 3 ]; then
    local f
    for f in "$DRUPAL_ROOT/log/supervisor/drupal.log" "$DRUPAL_ROOT/log/runserver.log" "$DRUPAL_ROOT/log/mysql.log"; do
      [ -f "$f" ] && { log "--- tail $f"; tail -n 40 "$f"; }
    done
    supervisorctl status 2>/dev/null
  fi
  upload_artifacts "$2"
  sleep 2  # let tee flush to stdout before the container exits
  exit "$1"
}

# ------------------------------------------------------------------------------
# start
# ------------------------------------------------------------------------------
log "context=$STATUS_CONTEXT ref=$GIT_REF sha=$GIT_SHA drupal=$DRUPAL execution=$EXECUTION"

# services (mysql + drush runserver) boot while we unpack
mkdir -p "$DRUPAL_ROOT/log/supervisor"
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &

if [ -n "$SRC_TARBALL" ]; then
  if [ ! -f "$SRC_DIR/$SRC_TARBALL" ]; then
    finish 3 "Source tarball not found: $SRC_DIR/$SRC_TARBALL"
  fi
  log "extract $SRC_DIR/$SRC_TARBALL -> $REPO_PATH"
  rm -rf "$REPO_PATH" && mkdir -p "$REPO_PATH" \
    && tar -xzf "$SRC_DIR/$SRC_TARBALL" -C "$REPO_PATH" --strip-components=1 \
    || finish 3 "Extract failed"
else
  log "SRC_TARBALL empty, using existing code at $REPO_PATH"
fi
[ -f "$REPO_PATH/civicrm-version.txt" ] || finish 3 "No netiCRM code at $REPO_PATH"
[ -f "$REPO_PATH/.ci-source" ] && log "source: $(cat "$REPO_PATH/.ci-source")"

# ------------------------------------------------------------------------------
# install (init.sh waits for mysqld and drush runserver itself, and never
# returns if drupal fails to install, hence the timeout)
# ------------------------------------------------------------------------------
cd "$REPO_PATH"
log "running /init.sh (timeout ${INIT_TIMEOUT}s)"
timeout "$INIT_TIMEOUT" /init.sh &
init_pid=$!
# init.sh loops forever waiting for runserver when drush site-install fails
# (no settings.php), so bail out early instead of waiting for INIT_TIMEOUT
waited=0
while kill -0 "$init_pid" 2>/dev/null; do
  sleep 10
  waited=$((waited + 10))
  if [ "$waited" -ge "$SETTINGS_TIMEOUT" ] && [ ! -f "$DRUPAL_ROOT/sites/default/settings.php" ]; then
    pkill -P "$init_pid"; kill "$init_pid" 2>/dev/null
    finish 4 "Drupal not installed after ${SETTINGS_TIMEOUT}s (no settings.php)"
  fi
done
wait "$init_pid"
init_rc=$?
[ "$init_rc" -eq 124 ] && finish 4 "Install timed out after ${INIT_TIMEOUT}s"
code=$(curl -s -o /dev/null -w '%{http_code}' -m 30 "http://127.0.0.1:${RUNPORT}/")
log "init.sh exit $init_rc, drupal http check -> $code"
case "$code" in
  2??|3??) ;;
  *) finish 4 "Install failed (HTTP $code)" ;;
esac

# ------------------------------------------------------------------------------
# tests
# ------------------------------------------------------------------------------
RUN_ALL="$REPO_PATH/tests/ci/run-all.sh"
[ -f "$RUN_ALL" ] || RUN_ALL=/usr/local/bin/run-all.sh
run_args=()
[ -n "$RUN_ONLY" ] && run_args+=(--only "$RUN_ONLY")
# RUN_ALL_ARGS is intentionally unquoted: multiple CLI args
run_args+=($RUN_ALL_ARGS)
log "running $RUN_ALL ${run_args[*]}"
CI_RESULT_FILE="$RESULT_FILE" bash "$RUN_ALL" "${run_args[@]}"
rc=$?

passed=$(grep -c '^passed' "$RESULT_FILE" 2>/dev/null)
failed_name=$(grep -m1 '^failed' "$RESULT_FILE" 2>/dev/null | cut -f3)
case "$rc" in
  0) finish 0 "All ${passed} steps passed" ;;
  1) finish 1 "Failed: ${failed_name} (${passed} passed before)" ;;
  *) finish "$rc" "run-all.sh error (exit $rc)" ;;
esac

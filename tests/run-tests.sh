#!/bin/bash
# 簡易測試 harness：以 test mode source 主腳本後驗證各函數行為
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/../illumio-backup.sh"

PASS=0
FAIL=0

assert_eq() {
    local DESC="$1" EXPECTED="$2" ACTUAL="$3"
    if [[ "$EXPECTED" == "$ACTUAL" ]]; then
        PASS=$((PASS+1)); echo "PASS: $DESC"
    else
        FAIL=$((FAIL+1)); echo "FAIL: $DESC (expected='$EXPECTED' actual='$ACTUAL')"
    fi
}

assert_exit() {
    local DESC="$1" EXPECTED="$2"; shift 2
    "$@" >/dev/null 2>&1
    local ACTUAL=$?
    assert_eq "$DESC" "$EXPECTED" "$ACTUAL"
}

assert_contains() {
    local DESC="$1" NEEDLE="$2" HAYSTACK="$3"
    if [[ "$HAYSTACK" == *"$NEEDLE"* ]]; then
        PASS=$((PASS+1)); echo "PASS: $DESC"
    else
        FAIL=$((FAIL+1)); echo "FAIL: $DESC (未包含 '$NEEDLE')"
    fi
}

# --- 載入主腳本（test mode 只載入函數定義，不執行主流程） ---
ILLUMIO_BACKUP_TEST_MODE=true
# shellcheck disable=SC1090
source "$SCRIPT" --local
# 測試中不寫 log 檔、不打 syslog
log() { :; }

# --- is_positive_int ---
assert_exit "is_positive_int 接受 1"       0 is_positive_int 1
assert_exit "is_positive_int 接受 30"      0 is_positive_int 30
assert_exit "is_positive_int 拒絕 0"       1 is_positive_int 0
assert_exit "is_positive_int 拒絕 -1"      1 is_positive_int -1
assert_exit "is_positive_int 拒絕 abc"     1 is_positive_int abc
assert_exit "is_positive_int 拒絕空字串"   1 is_positive_int ""

echo "-----------------------------------------"
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "$FAIL" -eq 0 ]]

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

# --- calendar_days_since（日曆天計算，修正 off-by-one） ---
NOW_EPOCH=$(date +%s)
YESTERDAY_LATE=$(date -d "$(date -d yesterday +%F) 23:00" +%s)
EIGHT_DAYS_AGO=$(date -d "$(date -d '8 days ago' +%F) 02:00" +%s)
assert_eq "calendar_days_since 今天任何時刻為 0"          0 "$(calendar_days_since "$NOW_EPOCH")"
assert_eq "calendar_days_since 昨天 23:00 為 1（跨日即 1 天）" 1 "$(calendar_days_since "$YESTERDAY_LATE")"
assert_eq "calendar_days_since 8 天前為 8"                8 "$(calendar_days_since "$EIGHT_DAYS_AGO")"

# --- retention 與 interval 一致性驗證 ---
OUT=$(bash "$SCRIPT" --local --db-interval 10 --retention-db 7 2>&1); RC=$?
assert_eq       "retention-db < db-interval 應 exit 1" 1 "$RC"
assert_contains "錯誤訊息說明 retention 不可小於 interval" "不可小於" "$OUT"
OUT=$(bash "$SCRIPT" --local --traffic-interval 30 2>&1); RC=$?
assert_eq       "retention-traffic(預設14) < traffic-interval 30 應 exit 1" 1 "$RC"

# --- 缺值參數應乾淨報錯（而非 set -u 的 unbound variable） ---
OUT=$(bash "$SCRIPT" --local --db-interval 2>&1); RC=$?
assert_eq       "--db-interval 缺值應 exit 1"      1 "$RC"
assert_contains "缺值錯誤訊息為自訂中文訊息"       "需要一個正整數" "$OUT"

echo "-----------------------------------------"
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "$FAIL" -eq 0 ]]

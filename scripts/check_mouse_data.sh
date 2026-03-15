#!/bin/bash
# check_mouse_data.sh — View mouse movement data stored in mouse.db

DB="$HOME/Library/Application Support/KeyLens/mouse.db"
PTS_PER_MM=0.353  # 1 macOS point ≈ 0.353 mm

if [ ! -f "$DB" ]; then
    echo "mouse.db not found. Launch KeyLens first and wait 30 seconds."
    exit 1
fi

echo "=== Mouse Move Distance — Daily ==="
sqlite3 "$DB" <<SQL
.headers on
.mode column
.width 12 10 10 10 10 10 10 10
SELECT
    date,
    printf('%.0f', distance_pts)               AS pts,
    printf('%.1f', distance_pts * 0.353 / 1000) AS meter,
    printf('%.0f', dx_pos)  AS dx_right,
    printf('%.0f', dx_neg)  AS dx_left,
    printf('%.0f', dy_pos)  AS dy_down,
    printf('%.0f', dy_neg)  AS dy_up
FROM mouse_daily
ORDER BY date DESC
LIMIT 14;
SQL

echo ""
echo "=== Hourly Breakdown (today) ==="
sqlite3 "$DB" <<SQL
.headers on
.mode column
.width 6 10 10
SELECT
    printf('%02d:00', hour)                      AS hour,
    printf('%.0f', distance_pts)                 AS pts,
    printf('%.1f', distance_pts * 0.353 / 1000)  AS meter
FROM mouse_hourly
WHERE date = date('now')
ORDER BY hour;
SQL

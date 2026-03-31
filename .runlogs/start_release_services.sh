#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/Quang/Downloads/SINH_VIEN/SINH_VIEN/SelfRestaurant-main"
DOTNET="/mnt/c/Program Files/dotnet/dotnet.exe"

pkill -f 'SelfRestaurant\.(Catalog|Orders|Customers|Identity|Billing)\.Api\.dll' || true
pkill -f 'SelfRestaurant\.Gateway\.Mvc\.dll' || true
sleep 2

start_one() {
  local dir="$1"
  local dll="$2"
  local url="$3"
  local out="$4"
  local err="$5"
  (
    cd "$dir"
    "$DOTNET" "$dll" --urls "$url" > "$out" 2> "$err" &
  )
}

start_one "$ROOT/src/Services/SelfRestaurant.Catalog.Api/bin/Release/net8.0" "SelfRestaurant.Catalog.Api.dll" "http://localhost:5101" "/tmp/catalog_phase4.out" "/tmp/catalog_phase4.err"
start_one "$ROOT/src/Services/SelfRestaurant.Orders.Api/bin/Release/net8.0" "SelfRestaurant.Orders.Api.dll" "http://localhost:5102" "/tmp/orders_phase4.out" "/tmp/orders_phase4.err"
start_one "$ROOT/src/Services/SelfRestaurant.Customers.Api/bin/Release/net8.0" "SelfRestaurant.Customers.Api.dll" "http://localhost:5103" "/tmp/customers_phase4.out" "/tmp/customers_phase4.err"
start_one "$ROOT/src/Services/SelfRestaurant.Identity.Api/bin/Release/net8.0" "SelfRestaurant.Identity.Api.dll" "http://localhost:5104" "/tmp/identity_phase4.out" "/tmp/identity_phase4.err"
start_one "$ROOT/src/Services/SelfRestaurant.Billing.Api/bin/Release/net8.0" "SelfRestaurant.Billing.Api.dll" "http://localhost:5105" "/tmp/billing_phase4.out" "/tmp/billing_phase4.err"
start_one "$ROOT/src/Gateway/SelfRestaurant.Gateway.Mvc/bin/Release/net8.0" "SelfRestaurant.Gateway.Mvc.dll" "http://localhost:5100" "/tmp/gateway_phase4.out" "/tmp/gateway_phase4.err"

sleep 8

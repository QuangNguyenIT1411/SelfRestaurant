set -e
BASE=http://localhost:5100
chef_cookie=$(mktemp)
cashier_cookie=$(mktemp)
admin_cookie=$(mktemp)
cleanup(){ rm -f "$chef_cookie" "$cashier_cookie" "$admin_cookie"; }
trap cleanup EXIT
chef_login=$(curl.exe -s -c "$chef_cookie" -b "$chef_cookie" -H "Content-Type: application/json" -d '{"username":"chef_hung","password":"123456"}' "$BASE/api/gateway/staff/auth/login")
chef_logout=$(curl.exe -s -c "$chef_cookie" -b "$chef_cookie" -H "Content-Type: application/json" -d '{}' "$BASE/api/gateway/staff/auth/logout")
cashier_login=$(curl.exe -s -c "$cashier_cookie" -b "$cashier_cookie" -H "Content-Type: application/json" -d '{"username":"cashier_lan","password":"123456"}' "$BASE/api/gateway/staff/auth/login")
cashier_logout=$(curl.exe -s -c "$cashier_cookie" -b "$cashier_cookie" -H "Content-Type: application/json" -d '{}' "$BASE/api/gateway/staff/cashier/auth/logout")
admin_login=$(curl.exe -s -c "$admin_cookie" -b "$admin_cookie" -H "Content-Type: application/json" -d '{"username":"admin","password":"123456"}' "$BASE/api/gateway/staff/auth/login")
admin_logout=$(curl.exe -s -c "$admin_cookie" -b "$admin_cookie" -H "Content-Type: application/json" -d '{}' "$BASE/api/gateway/admin/auth/logout")
python3 - <<'PY' "$chef_login" "$chef_logout" "$cashier_login" "$cashier_logout" "$admin_login" "$admin_logout"
import json,sys
items=[json.loads(x) for x in sys.argv[1:]]
print(json.dumps({
  'chefLoginNextPath': items[0].get('nextPath'),
  'chefLogoutNextPath': items[1].get('nextPath'),
  'cashierLoginNextPath': items[2].get('nextPath'),
  'cashierLogoutNextPath': items[3].get('nextPath'),
  'adminLoginNextPath': items[4].get('nextPath'),
  'adminLogoutNextPath': items[5].get('nextPath'),
}, ensure_ascii=False, indent=2))
PY

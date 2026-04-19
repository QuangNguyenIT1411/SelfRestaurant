import json
from datetime import datetime
from pathlib import Path

import requests

BASE = "http://localhost:5100"
CUSTOMER = f"{BASE}/api/gateway/customer"
STAFF = f"{BASE}/api/gateway/staff"
SUMMARY_PATH = Path(r"C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway_api_chef_smoke_summary.json")


def ensure_ok(resp, step):
    if resp.status_code >= 400:
        try:
            payload = resp.json()
        except Exception:
            payload = resp.text
        raise RuntimeError(f"{step} failed: {resp.status_code} {payload}")
    return resp


def main():
    customer_session = requests.Session()
    staff_session = requests.Session()

    # 1) Login chef first so we know the branch to target.
    chef_login = ensure_ok(
        staff_session.post(
            f"{STAFF}/auth/login",
            json={"username": "chef_hung", "password": "123456"},
            timeout=30,
        ),
        "chef login",
    ).json()
    staff = chef_login["session"]["staff"]
    branch_id = staff["branchId"]

    # 2) Pick a table in chef branch.
    tables = ensure_ok(customer_session.get(f"{CUSTOMER}/branches/{branch_id}/tables", timeout=30), "get branch tables").json()["tables"]
    if not tables:
        raise RuntimeError(f"No tables found for chef branch {branch_id}")
    table = next((t for t in tables if t.get("statusCode") != "OCCUPIED"), tables[0])
    ensure_ok(customer_session.post(f"{CUSTOMER}/context/table", json={"tableId": table["tableId"], "branchId": branch_id}, timeout=30), "set customer table context")

    # 3) Create a temp customer account.
    stamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    username = f"chef_api_{stamp}"
    password = "123456"
    phone = f"09{stamp[-8:]}"
    ensure_ok(
        customer_session.post(
            f"{CUSTOMER}/auth/register",
            json={
                "name": f"Chef Api {stamp}",
                "username": username,
                "password": password,
                "phoneNumber": phone,
                "email": f"{username}@example.com",
            },
            timeout=30,
        ),
        "register temp customer",
    )
    ensure_ok(customer_session.post(f"{CUSTOMER}/auth/login", json={"username": username, "password": password}, timeout=30), "customer login")

    # 4) Pick a dish from today's menu.
    menu = ensure_ok(customer_session.get(f"{CUSTOMER}/menu", timeout=30), "get customer menu").json()
    categories = menu["menu"]["categories"]
    dishes = [dish for category in categories for dish in category.get("dishes", []) if dish.get("available", True)]
    if not dishes:
        raise RuntimeError(f"No available dishes found in branch {branch_id} menu")
    dish = dishes[0]

    # 5) Create and submit order.
    ensure_ok(customer_session.post(f"{CUSTOMER}/order/items", json={"dishId": dish["dishId"], "quantity": 1, "note": "chef api smoke"}, timeout=30), "add order item")
    order_before_submit = ensure_ok(customer_session.get(f"{CUSTOMER}/order", timeout=30), "get active order before submit").json()
    order_id = order_before_submit["orderId"]
    item_id = order_before_submit["items"][0]["orderItemId"]
    ensure_ok(customer_session.post(f"{CUSTOMER}/order/submit", timeout=30), "submit order")

    # 6) Chef dashboard should now see the order.
    dashboard = ensure_ok(staff_session.get(f"{STAFF}/chef/dashboard", timeout=30), "get chef dashboard").json()
    pending_ids = [o["orderId"] for o in dashboard["pendingOrders"]]
    if order_id not in pending_ids:
        raise RuntimeError(f"Submitted order {order_id} not visible in chef pending list: {pending_ids}")

    # 7) Chef actions.
    ensure_ok(staff_session.patch(f"{STAFF}/chef/orders/{order_id}/items/{item_id}/note", json={"note": "checked by api chef", "append": True}, timeout=30), "chef update item note")
    ensure_ok(staff_session.post(f"{STAFF}/chef/orders/{order_id}/start", timeout=30), "chef start")
    ensure_ok(staff_session.post(f"{STAFF}/chef/orders/{order_id}/ready", timeout=30), "chef ready")
    ensure_ok(staff_session.post(f"{STAFF}/chef/orders/{order_id}/serve", timeout=30), "chef serve")

    # 8) Menu / ingredient / availability smoke.
    chef_menu = ensure_ok(staff_session.get(f"{STAFF}/chef/menu", timeout=30), "get chef menu").json()
    chef_dishes = chef_menu["dishes"]
    target_dish = next((d for d in chef_dishes if d["dishId"] == dish["dishId"]), chef_dishes[0] if chef_dishes else None)
    if target_dish is None:
        raise RuntimeError("Chef menu is empty")

    ingredients = ensure_ok(staff_session.get(f"{STAFF}/chef/dishes/{target_dish['dishId']}/ingredients", timeout=30), "get dish ingredients").json()
    items = ingredients.get("items", [])
    if items:
        ensure_ok(staff_session.put(f"{STAFF}/chef/dishes/{target_dish['dishId']}/ingredients", json={"items": items}, timeout=30), "save dish ingredients")
    original_available = bool(target_dish["available"])
    ensure_ok(staff_session.post(f"{STAFF}/chef/dishes/{target_dish['dishId']}/availability", json={"available": (not original_available)}, timeout=30), "toggle dish availability off/on 1")
    ensure_ok(staff_session.post(f"{STAFF}/chef/dishes/{target_dish['dishId']}/availability", json={"available": original_available}, timeout=30), "restore dish availability")

    history = ensure_ok(staff_session.get(f"{STAFF}/chef/history?take=20", timeout=30), "chef history").json()
    history_ids = [h["orderId"] for h in history]

    SUMMARY_PATH.write_text(json.dumps({
        "success": True,
        "branchId": branch_id,
        "orderId": order_id,
        "itemId": item_id,
        "dishId": target_dish["dishId"],
        "historyContainsOrder": order_id in history_ids,
        "timestampUtc": datetime.utcnow().isoformat() + "Z"
    }, indent=2), encoding="utf-8")
    print(f"PASS order={order_id} dish={target_dish['dishId']} branch={branch_id}")


if __name__ == "__main__":
    main()

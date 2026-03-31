function cleanupOtherStoredMenuCarts() {
    try {
        for (let i = localStorage.length - 1; i >= 0; i--) {
            const key = localStorage.key(i);
            if (!key || !key.startsWith("menuCart-")) {
                continue;
            }

            if (key !== cartStorageKey) {
                localStorage.removeItem(key);
            }
        }
    } catch (e) {
        console.warn("Không thể dọn giỏ hàng của bàn khác trong localStorage:", e.message);
    }
}

function normalizeDishImagePath(rawValue) {
    if (typeof rawValue !== "string") {
        return localPlaceholderDishImage;
    }

    let value = rawValue.trim();
    if (!value) {
        return localPlaceholderDishImage;
    }

    if (/^https?:\/\//i.test(value) || /^data:image\//i.test(value)) {
        return value;
    }

    value = value.replace(/\\/g, "/");

    if (value.startsWith("~/")) {
        value = "/" + value.substring(2);
    }

    if (!value.startsWith("/")) {
        value = "/" + value;
    }

    if (value.toLowerCase().startsWith("/images/")) {
        value = "/images/" + value.substring("/images/".length);
    }

    return value || localPlaceholderDishImage;
}

function resolveDishImage(dish) {
    if (!dish || typeof dish !== "object") {
        return localPlaceholderDishImage;
    }

    const rawImage = dish.Image ?? dish.image ?? null;
    return normalizeDishImagePath(rawImage);
}

function fallbackDishImage(imgElement) {
    if (!imgElement) {
        return;
    }

    imgElement.onerror = null;
    imgElement.src = localPlaceholderDishImage;
}

function renderReadyNotifications(notifications) {
    const area = document.getElementById("notificationArea");
    if (!area) return;

    if (!Array.isArray(notifications) || notifications.length === 0) {
        area.innerHTML = "";
        area.classList.add("d-none");
        return;
    }

    area.classList.remove("d-none");
    area.innerHTML = notifications.map(item => `
        <div class="notification-item shadow-sm border border-success-subtle bg-white">
            <div class="d-flex justify-content-between align-items-start gap-3">
                <div>
                    <div class="fw-bold text-success mb-1">
                        <i class="bi bi-bell-fill me-1"></i>Món đã sẵn sàng
                    </div>
                    <div class="small text-muted">${item.message || "Bếp đã hoàn thành món ăn cho bạn."}</div>
                </div>
                <button type="button"
                        class="btn btn-sm btn-outline-success"
                        onclick="openReadyNotification(${item.readyDishNotificationId}, ${item.orderId})">
                    Nhận món
                </button>
            </div>
        </div>
    `).join("");
}

function pollReadyNotificationsOnce() {
    fetch(getReadyNotificationsUrl + tableID, {
        method: 'GET',
        headers: { 'X-Requested-With': 'XMLHttpRequest' }
    })
    .then(r => r.ok ? r.json() : null)
    .then(data => {
        if (!data || !data.success) return;

        const notifications = Array.isArray(data.notifications) ? data.notifications : [];
        renderReadyNotifications(notifications);

        if (notifications.length > 0) {
            const latest = notifications[0];
            activeReadyNotificationId = latest.readyDishNotificationId || null;
        } else {
            activeReadyNotificationId = null;
        }
    })
    .catch(() => { });
}

function openReadyNotification(notificationId, orderId) {
    if (notificationId) {
        activeReadyNotificationId = notificationId;
    }
    if (orderId) {
        currentOrderId = orderId;
    }

    try {
        var readyModalEl = document.getElementById("orderReadyModal");
        if (!readyModalEl) return;
        var readyModal = bootstrap.Modal.getOrCreateInstance(readyModalEl);
        readyModal.show();
    } catch (e) {
        console.warn("Không thể hiển thị modal nhận món:", e.message);
    }
}

function pickValue(source, keys, fallback = null) {
    if (!source || typeof source !== "object" || !Array.isArray(keys)) {
        return fallback;
    }

    for (const key of keys) {
        if (Object.prototype.hasOwnProperty.call(source, key) && source[key] !== undefined && source[key] !== null) {
            return source[key];
        }
    }

    return fallback;
}

function getOrderId(order) {
    const raw = pickValue(order, ["OrderID", "orderID", "orderId"], 0);
    return Number(raw) || 0;
}

function getOrderStatusCode(order) {
    const raw = pickValue(order, ["StatusCode", "statusCode"], "");
    return String(raw || "").toUpperCase().trim();
}

function getOrderItems(order) {
    const items = pickValue(order, ["Items", "items"], []);
    return Array.isArray(items) ? items : [];
}

function mapOrderItemToCart(item, statusLabel) {
    return {
        DishID: Number(pickValue(item, ["DishID", "dishID", "dishId"], 0)) || 0,
        Name: String(pickValue(item, ["DishName", "dishName"], "")),
        Price: Number(pickValue(item, ["UnitPrice", "unitPrice"], 0)) || 0,
        Unit: String(pickValue(item, ["Unit", "unit"], "")),
        quantity: Number(pickValue(item, ["Quantity", "quantity"], 0)) || 0,
        status: statusLabel,
        note: String(pickValue(item, ["Note", "note"], "")),
        Image: pickValue(item, ["Image", "image"], null)
    };
}

function hasActiveOrderStateInClient() {
    if (currentOrderId) {
        return true;
    }

    return Array.isArray(cart) && cart.some(function (item) {
        var status = String(item && item.status ? item.status : "").toLowerCase();
        return status === "preparing" || status === "ready" || status === "served";
    });
}

function clearOrderStateInClient() {
    currentOrderId = null;
    cart = [];
    pendingItems = [];
    readyPromptedOrderIds = {};
    renderCart();
    updateSendButton();
    try {
        localStorage.removeItem(cartStorageKey);
    } catch (e) {
        console.warn("Không thể xóa giỏ hàng khỏi localStorage:", e.message);
    }
}

function clearCurrentTableContextOnServer() {
    var tokenElement = document.querySelector('input[name="__RequestVerificationToken"]');
    var tokenValue = tokenElement ? tokenElement.value : "";
    if (!tokenValue || !clearCurrentTableContextUrl) {
        return Promise.resolve();
    }

    return fetch(clearCurrentTableContextUrl, {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest"
        },
        body: "__RequestVerificationToken=" + encodeURIComponent(tokenValue)
    }).catch(function () {
        return null;
    });
}

function handleOrderCompletedAndResetTableContext() {
    if (isClearingTableContext) {
        return;
    }

    isClearingTableContext = true;
    clearOrderStateInClient();

    clearCurrentTableContextOnServer()
        .finally(function () {
            showToast("success", "Thu ngân đã thanh toán xong. Bàn đã được giải phóng.");
            setTimeout(function () {
                window.location.href = homeIndexUrl;
            }, 1000);
        });
}

function startOrderStatusWatcher() {
    if (!tableID || tableID <= 0 || !getTableOrderStatusesUrl) return;

    if (orderStatusTimer) {
        clearInterval(orderStatusTimer);
    }

    function showOrderReadyModal() {
        try {
            var readyModalEl = document.getElementById("orderReadyModal");
            if (!readyModalEl) return;

            var readyModal = bootstrap.Modal.getOrCreateInstance(readyModalEl);
            readyModal.show();
        } catch (e) {
            console.warn("Không thể hiển thị modal xác nhận nhận món:", e.message);
        }
    }

    function hideOrderReadyModal() {
        try {
            var readyModalEl = document.getElementById("orderReadyModal");
            if (!readyModalEl) return;

            var readyModal = bootstrap.Modal.getInstance(readyModalEl);
            if (readyModal) {
                readyModal.hide();
            }
        } catch (e) {
            console.warn("Không thể đóng modal xác nhận nhận món:", e.message);
        }
    }

    function syncCartWithOrderItems(order, statusLabel) {
        var orderItems = getOrderItems(order);
        if (!orderItems.length) return;

        cart = orderItems.map(function (i) { return mapOrderItemToCart(i, statusLabel); });
        pendingItems = [];
        renderCart();
        updateSendButton();
        saveCartToStorage();
    }

    function applyOrdersState(orders) {
        if (!Array.isArray(orders) || orders.length === 0) {
            hideOrderReadyModal();
            if (hasActiveOrderStateInClient()) {
                handleOrderCompletedAndResetTableContext();
            }
            return;
        }

        var normalizedOrders = orders
            .slice()
            .sort(function (a, b) {
                return getOrderId(a) - getOrderId(b);
            });

        var readyOrder = normalizedOrders.find(function (o) {
            return getOrderStatusCode(o) === "READY";
        });

        if (readyOrder) {
            currentOrderId = getOrderId(readyOrder) || currentOrderId;
            syncCartWithOrderItems(readyOrder, "ready");

            if (currentOrderId && !readyPromptedOrderIds[currentOrderId]) {
                readyPromptedOrderIds[currentOrderId] = true;
                showToast("success", "Món ăn đã sẵn sàng, vui lòng nhận món ăn.");
            }

            showOrderReadyModal();
            return;
        }

        var latestOrder = normalizedOrders[normalizedOrders.length - 1];
        currentOrderId = getOrderId(latestOrder) || currentOrderId;
        var latestStatus = getOrderStatusCode(latestOrder);
        if (latestStatus === "PENDING" || latestStatus === "CONFIRMED" || latestStatus === "PREPARING") {
            syncCartWithOrderItems(latestOrder, "preparing");
            hideOrderReadyModal();
            return;
        }

        if (latestStatus === "SERVING" || latestStatus === "COMPLETED") {
            syncCartWithOrderItems(latestOrder, "served");
            hideOrderReadyModal();
        }
    }

    function pollOrderStatusOnce() {
        fetch(getTableOrderStatusesUrl + tableID, {
            method: "GET",
            headers: { "X-Requested-With": "XMLHttpRequest" }
        })
        .then(r => r.ok ? r.json() : null)
        .then(data => {
            if (!data || !data.success) return;
            applyOrdersState(pickValue(data, ["orders", "Orders"], []));
        })
        .catch(() => { });
    }

    pollOrderStatusOnce();
    orderStatusTimer = setInterval(pollOrderStatusOnce, 2000);

    pollReadyNotificationsOnce();
    if (readyNotificationTimer) {
        clearInterval(readyNotificationTimer);
    }
    readyNotificationTimer = setInterval(pollReadyNotificationsOnce, 4000);
}

function confirmOrderReceived() {
    if (!currentOrderId || confirmingOrderReceived) return;

    var tokenElement = document.querySelector('input[name="__RequestVerificationToken"]');
    if (!tokenElement) {
        showToast("error", "Không tìm thấy token bảo mật. Vui lòng tải lại trang.");
        return;
    }

    var tokenValue = tokenElement.value;
    var confirmBtn = document.getElementById("btnConfirmOrderReceived");
    var originalBtnHtml = confirmBtn ? confirmBtn.innerHTML : "";

    confirmingOrderReceived = true;
    if (confirmBtn) {
        confirmBtn.disabled = true;
        confirmBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Đang xác nhận...';
    }

    fetch(confirmOrderReceivedUrl, {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "X-Requested-With": "XMLHttpRequest"
        },
        body: "orderId=" + encodeURIComponent(currentOrderId) +
            "&__RequestVerificationToken=" + encodeURIComponent(tokenValue)
    })
    .then(function (response) { return response.json(); })
    .then(function (data) {
        if (data && data.requiresLogin && data.loginUrl) {
            showToast("warning", "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.");
            window.location.href = data.loginUrl;
            return;
        }

        if (data && data.success) {
            showToast("success", data.message || "Đã xác nhận nhận món. Chúc ngon miệng!");

            cart = (cart || []).map(function (item) {
                return {
                    ...item,
                    status: "served"
                };
            });
            renderCart();

            if (currentOrderId) {
                readyPromptedOrderIds[currentOrderId] = true;
            }

            if (activeReadyNotificationId) {
                const resolveForm = new FormData();
                resolveForm.append("notificationId", activeReadyNotificationId);
                resolveForm.append("__RequestVerificationToken", tokenValue);
                fetch(resolveReadyNotificationUrl, {
                    method: "POST",
                    body: resolveForm,
                    headers: { "X-Requested-With": "XMLHttpRequest" }
                }).catch(() => { });

                activeReadyNotificationId = null;
                pollReadyNotificationsOnce();
            }
        } else {
            showToast("error", (data && data.message) || "Không thể xác nhận nhận món.");
        }

        try {
            var readyModalEl = document.getElementById("orderReadyModal");
            if (readyModalEl) {
                var readyModal = bootstrap.Modal.getInstance(readyModalEl);
                if (readyModal) {
                    readyModal.hide();
                }
            }
        } catch (e) {
            console.warn("Không thể đóng modal xác nhận nhận món:", e.message);
        }
    })
    .catch(function (error) {
        console.error("ConfirmOrderReceived error:", error);
        showToast("error", "Có lỗi xảy ra khi xác nhận nhận món.");
    })
    .finally(function () {
        confirmingOrderReceived = false;
        if (confirmBtn) {
            confirmBtn.disabled = false;
            confirmBtn.innerHTML = originalBtnHtml;
        }
    });
}

function finishPaymentProcess() {
    showToast("info", "Yêu cầu thanh toán đã được ghi nhận. Vui lòng chờ thu ngân xác nhận.");
}

function restoreCartFromExistingOrder() {
    if (!currentOrderId || !getActiveOrderUrl) return;

    fetch(getActiveOrderUrl + currentOrderId, {
        method: "GET",
        headers: { "X-Requested-With": "XMLHttpRequest" }
    })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (data) {
        var order = pickValue(data, ["order", "Order"], null);
        if (!data || !data.success || !order) return;

        var items = getOrderItems(order);
        if (!items.length) return;

        cart = items.map(function (i) {
            var normalizedStatus = "preparing";
            var statusCode = getOrderStatusCode(order);
            if (statusCode === "READY") {
                normalizedStatus = "ready";
            } else if (statusCode === "SERVING" || statusCode === "COMPLETED") {
                normalizedStatus = "served";
            }

            return mapOrderItemToCart(i, normalizedStatus);
        });
        pendingItems = [];
        renderCart();
        updateSendButton();
        saveCartToStorage();
    })
    .catch(function (e) {
        console.warn("Không thể khôi phục giỏ hàng từ đơn hiện tại:", e.message);
    });
}

function confirmResetTable() {
    clearOrderStateInClient();

    const token = document.querySelector('input[name="__RequestVerificationToken"]')?.value || "";
    const form = document.createElement("form");
    form.method = "POST";
    form.action = resetTableUrl;
    form.innerHTML = `
        <input type="hidden" name="tableId" value="${tableID}">
        <input type="hidden" name="branchId" value="${branchId}">
        <input type="hidden" name="__RequestVerificationToken" value="${token}">
    `;
    document.body.appendChild(form);
    form.submit();
}

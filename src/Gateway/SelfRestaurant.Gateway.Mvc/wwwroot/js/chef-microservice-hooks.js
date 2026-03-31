(function () {
    var config = window.chefPageConfig || {};
    var chefMenu = config.chefMenu || [];
    var chefIngredients = config.chefIngredients || [];
    var currentIngredientsDishId = null;
    var currentOrderItemId = null;
    var chefBoardRefreshTimer = null;
    var isChefOrderMutationInProgress = false;

    function refreshOrdersBoard() {
        if (isChefOrderMutationInProgress) {
            return;
        }

        var container = document.getElementById('chefOrdersBoardContainer');
        if (!container || !config.urls || !config.urls.getOrdersBoard) {
            return;
        }

        $.ajax({
            url: config.urls.getOrdersBoard,
            method: 'GET',
            cache: false
        })
            .done(function (html) {
                if (typeof html === 'string' && html.trim().length > 0) {
                    container.innerHTML = html;
                }
            })
            .fail(function () {
                // Best-effort polling.
            });
    }

    function startChefBoardAutoRefresh() {
        if (chefBoardRefreshTimer) {
            clearInterval(chefBoardRefreshTimer);
        }

        refreshOrdersBoard();
        chefBoardRefreshTimer = setInterval(refreshOrdersBoard, 2000);
    }

    function updateStatus(orderId, status) {
        if (!confirm('Xác nhận chuyển trạng thái đơn hàng?')) return;

        isChefOrderMutationInProgress = true;
        $.post(config.urls.updateOrderStatus, {
            orderId: orderId,
            statusCode: status
        })
            .done(function (res) {
                if (res.success) {
                    refreshOrdersBoard();
                } else {
                    alert(res.message);
                }
            })
            .fail(function () {
                alert('Có lỗi xảy ra khi kết nối server');
            })
            .always(function () {
                isChefOrderMutationInProgress = false;
            });
    }

    function openCancelOrderModal(orderId) {
        document.getElementById('cancelOrderId').value = orderId;
        document.getElementById('cancelReason').value = '';

        var modal = new bootstrap.Modal(document.getElementById('cancelOrderModal'));
        modal.show();
    }

    function confirmCancelOrder() {
        var orderId = parseInt(document.getElementById('cancelOrderId').value);
        var reason = (document.getElementById('cancelReason').value || '').trim();

        if (!orderId || orderId <= 0) {
            alert('Đơn hàng không hợp lệ.');
            return;
        }
        if (!reason) {
            alert('Vui lòng nhập lý do hủy đơn.');
            return;
        }
        if (!confirm('Bạn chắc chắn muốn hủy đơn này?')) {
            return;
        }

        isChefOrderMutationInProgress = true;
        $.post(config.urls.cancelOrder, {
            orderId: orderId,
            reason: reason
        })
            .done(function (res) {
                if (res && res.success) {
                    alert(res.message || 'Đã hủy đơn hàng.');
                    refreshOrdersBoard();
                } else {
                    alert(res && res.message ? res.message : 'Không thể hủy đơn hàng.');
                }
            })
            .fail(function () {
                alert('Không kết nối được đến máy chủ.');
            })
            .always(function () {
                isChefOrderMutationInProgress = false;
            });
    }

    function setDishAvailability(dishId, isAvailable) {
        var url = isAvailable ? config.urls.showDish : config.urls.hideDish;
        var confirmMessage = isAvailable
            ? 'Bạn có chắc muốn mở bán lại món này?'
            : 'Bạn có chắc muốn tạm ngưng bán món này?';

        if (!confirm(confirmMessage)) return;

        $.post(url, { dishId: dishId })
            .done(function (res) {
                if (res.success) {
                    alert(res.message);
                    window.location.reload();
                } else {
                    alert(res.message);
                }
            });
    }

    function postDishData(data) {
        $.post(config.urls.addDish, data)
            .done(function (res) {
                if (res.success) {
                    var msg = res.message || ('Đã thêm món "' + (data.name || '') + '" vào menu hôm nay.');
                    alert(msg);
                    window.location.reload();
                } else {
                    alert(res.message);
                }
            });
    }

    function submitAddDish() {
        var formData = new FormData(document.getElementById('addDishForm'));
        var data = Object.fromEntries(formData.entries());
        var name = (data.name || '').trim();
        var priceText = (data.price || '').trim();
        var unit = (data.unit || '').trim();
        var categoryId = parseInt(data.categoryId || '0');

        if (!name) {
            alert('Vui lòng nhập tên món ăn.');
            return;
        }
        if (!priceText) {
            alert('Vui lòng nhập giá món ăn.');
            return;
        }
        if (isNaN(parseFloat(priceText))) {
            alert('Giá món ăn phải là số và không được chứa chữ.');
            return;
        }
        if (!unit) {
            alert('Vui lòng nhập đơn vị (ví dụ: Dĩa, Tô...).');
            return;
        }
        if (!categoryId || categoryId <= 0) {
            alert('Vui lòng chọn danh mục hợp lệ.');
            return;
        }

        data.isVegetarian = document.getElementById('isVeg').checked;
        data.isDailySpecial = document.getElementById('isSpecial').checked;
        data.available = document.getElementById('dishAvailable').checked;

        var fileInput = document.getElementById('dishImageFile');
        if (fileInput.files && fileInput.files[0]) {
            var reader = new FileReader();
            reader.onload = function (e) {
                data.image = e.target.result;
                postDishData(data);
            };
            reader.readAsDataURL(fileInput.files[0]);
        } else {
            postDishData(data);
        }
    }

    function handleLogout() {
        if (confirm('Bạn có chắc chắn muốn đăng xuất?')) {
            window.location.href = config.urls.logout;
        }
    }

    function resetAddDishForm() {
        var form = document.getElementById('addDishForm');
        if (!form) return;
        form.reset();
        var img = document.getElementById('dishImagePreview');
        if (img) {
            img.src = 'https://placehold.co/120x80?text=Preview';
        }
    }

    function openEditDishModal(dishId) {
        var dish = (chefMenu || []).find(function (d) { return d.id === dishId; });
        if (!dish) {
            alert('Không tìm thấy thông tin món ăn.');
            return;
        }

        document.getElementById('editDishId').value = dish.id;
        document.getElementById('editName').value = dish.name || '';
        document.getElementById('editPrice').value = dish.price || 0;
        document.getElementById('editUnit').value = dish.unit || '';
        document.getElementById('editCategoryName').value = dish.categoryName || '';
        document.getElementById('editDescription').value = dish.description || '';
        document.getElementById('editIsVegetarian').checked = !!dish.isVegetarian;
        document.getElementById('editIsSpecial').checked = !!dish.isDailySpecial;

        var img = document.getElementById('editDishImagePreview');
        img.src = dish.image || 'https://placehold.co/120x80?text=Preview';

        var modal = new bootstrap.Modal(document.getElementById('editDishModal'));
        modal.show();
    }

    function postEditDishData(data) {
        $.post(config.urls.editDish, data)
            .done(function (res) {
                if (res.success) {
                    alert(res.message || 'Đã cập nhật thông tin món ăn.');
                    window.location.reload();
                } else {
                    alert(res.message);
                }
            });
    }

    function submitEditDish() {
        var data = {
            dishId: parseInt(document.getElementById('editDishId').value),
            name: document.getElementById('editName').value.trim(),
            price: document.getElementById('editPrice').value.trim(),
            unit: document.getElementById('editUnit').value.trim(),
            description: document.getElementById('editDescription').value.trim(),
            isVegetarian: document.getElementById('editIsVegetarian').checked,
            isDailySpecial: document.getElementById('editIsSpecial').checked
        };

        if (!data.name) {
            alert('Vui lòng nhập tên món ăn.');
            return;
        }
        if (!data.price) {
            alert('Vui lòng nhập giá món ăn.');
            return;
        }
        if (isNaN(parseFloat(data.price))) {
            alert('Giá món ăn phải là số và không được chứa chữ.');
            return;
        }
        if (!data.unit) {
            alert('Vui lòng nhập đơn vị (ví dụ: Dĩa, Tô...).');
            return;
        }

        var fileInput = document.getElementById('editDishImageFile');
        if (fileInput.files && fileInput.files[0]) {
            var reader = new FileReader();
            reader.onload = function (e) {
                data.image = e.target.result;
                postEditDishData(data);
            };
            reader.readAsDataURL(fileInput.files[0]);
        } else {
            postEditDishData(data);
        }
    }

    function renderMenuGrid() {
        var search = (document.getElementById('dishSearchInput').value || '').toLowerCase();
        var statusFilter = document.getElementById('dishStatusFilter').value;
        var specialFilter = document.getElementById('dishSpecialFilter').value;

        document.querySelectorAll('.menu-grid .dish-card').forEach(function (card) {
            var name = (card.getAttribute('data-name') || '').toLowerCase();
            var available = card.getAttribute('data-available') === 'true';
            var isSpecial = card.getAttribute('data-special') === 'true';
            var show = true;

            if (search && name.indexOf(search) === -1) show = false;
            if (statusFilter === 'AVAILABLE' && !available) show = false;
            if (statusFilter === 'PAUSED' && available) show = false;
            if (specialFilter === 'SPECIAL' && !isSpecial) show = false;
            if (specialFilter === 'NORMAL' && isSpecial) show = false;

            card.style.display = show ? '' : 'none';
        });
    }

    function openDishIngredients(dishId) {
        currentIngredientsDishId = dishId;
        document.getElementById('ingredientsDishId').value = dishId;
        document.getElementById('ingredientQuantity').value = '';
        document.getElementById('ingredientSelect').value = '';
        document.getElementById('ingredientUnitLabel').textContent = '--';
        document.getElementById('dishIngredientsTableBody').innerHTML = '<tr><td colspan="4" class="text-center text-muted">Đang tải...</td></tr>';

        $.get(config.urls.getDishIngredients, { dishId: dishId })
            .done(function (res) {
                if (res && res.success) {
                    document.getElementById('dishIngredientsTitle').textContent = res.dishName || '';
                    renderDishIngredientsTable(res.items || []);
                } else {
                    alert(res && res.message ? res.message : 'Không tải được thành phần món ăn.');
                }
            })
            .fail(function () {
                alert('Không kết nối được đến máy chủ.');
            });

        var modal = new bootstrap.Modal(document.getElementById('dishIngredientsModal'));
        modal.show();
    }

    function renderDishIngredientsTable(items) {
        var tbody = document.getElementById('dishIngredientsTableBody');
        if (!tbody) return;

        tbody.innerHTML = '';

        if (!items || !items.length) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">Chưa khai báo thành phần cho món ăn này.</td></tr>';
            return;
        }

        items.forEach(function (item) {
            var row = document.createElement('tr');
            row.innerHTML =
                '<td>' + (item.ingredientName || '') + '</td>' +
                '<td class="text-end">' + (Number(item.quantityPerDish || 0).toFixed(2)) + '</td>' +
                '<td>' + (item.unit || '') + '</td>' +
                '<td class="text-end">' +
                '  <button class="btn btn-sm btn-outline-danger" onclick="removeDishIngredient(' + item.id + ')">' +
                '    <i class="bi bi-trash"></i>' +
                '  </button>' +
                '</td>';
            tbody.appendChild(row);
        });
    }

    function saveDishIngredient() {
        var dishId = currentIngredientsDishId || parseInt(document.getElementById('ingredientsDishId').value);
        var ingredientId = parseInt(document.getElementById('ingredientSelect').value);
        var quantity = parseFloat((document.getElementById('ingredientQuantity').value || '0').replace(',', '.'));

        if (!dishId || dishId <= 0) {
            alert('Món ăn không hợp lệ.');
            return;
        }
        if (!ingredientId || ingredientId <= 0) {
            alert('Vui lòng chọn nguyên liệu.');
            return;
        }
        if (isNaN(quantity) || quantity <= 0) {
            alert('Số lượng / 1 phần phải lớn hơn 0.');
            return;
        }

        $.post(config.urls.addDishIngredient, {
            dishId: dishId,
            ingredientId: ingredientId,
            quantityPerDish: quantity
        })
            .done(function (res) {
                if (res && res.success) {
                    $.get(config.urls.getDishIngredients, { dishId: dishId })
                        .done(function (r) {
                            if (r && r.success) {
                                renderDishIngredientsTable(r.items || []);
                                document.getElementById('ingredientQuantity').value = '';
                            }
                        });
                } else {
                    alert(res && res.message ? res.message : 'Không lưu được thành phần.');
                }
            })
            .fail(function (xhr, status, error) {
                console.error('Lỗi AddDishIngredient', status, error, xhr && xhr.responseText);
                alert('Không kết nối được đến máy chủ (AddDishIngredient).');
            });
    }

    function removeDishIngredient(id) {
        if (!confirm('Bạn có chắc chắn muốn xóa thành phần này khỏi món ăn?')) {
            return;
        }

        $.post(config.urls.removeDishIngredient, { id: id })
            .done(function (res) {
                if (res && res.success) {
                    if (currentIngredientsDishId) {
                        $.get(config.urls.getDishIngredients, { dishId: currentIngredientsDishId })
                            .done(function (r) {
                                if (r && r.success) {
                                    renderDishIngredientsTable(r.items || []);
                                }
                            });
                    }
                } else {
                    alert(res && res.message ? res.message : 'Không xóa được thành phần.');
                }
            })
            .fail(function (xhr, status, error) {
                console.error('Lỗi RemoveDishIngredient', status, error, xhr && xhr.responseText);
                alert('Không kết nối được đến máy chủ (RemoveDishIngredient).');
            });
    }

    function openOrderItemIngredients(orderItemId) {
        currentOrderItemId = orderItemId;
        document.getElementById('orderItemIdInput').value = orderItemId;

        var tbody = document.getElementById('orderItemIngredientsTableBody');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">Đang tải...</td></tr>';
        }

        $.get(config.urls.getOrderItemIngredients, { orderItemId: orderItemId })
            .done(function (res) {
                if (res && res.success) {
                    document.getElementById('orderItemDishTitle').textContent = res.dishName || '';
                    renderOrderItemIngredientsTable(res.items || []);
                } else {
                    alert(res && res.message ? res.message : 'Không tải được thành phần cho đơn này.');
                }
            })
            .fail(function () {
                alert('Không kết nối được đến máy chủ.');
            });

        var modal = new bootstrap.Modal(document.getElementById('orderItemIngredientsModal'));
        modal.show();
    }

    function renderOrderItemIngredientsTable(items) {
        var tbody = document.getElementById('orderItemIngredientsTableBody');
        if (!tbody) return;

        tbody.innerHTML = '';

        if (!items || !items.length) {
            var tr = document.createElement('tr');
            var td = document.createElement('td');
            td.colSpan = 4;
            td.className = 'text-center text-muted';
            td.textContent = 'Chưa có thành phần nào.';
            tr.appendChild(td);
            tbody.appendChild(tr);
            return;
        }

        items.forEach(function (item) {
            var tr = document.createElement('tr');
            tr.setAttribute('data-ingredient-id', item.ingredientId);

            var tdName = document.createElement('td');
            tdName.textContent = item.ingredientName || ('Nguyên liệu #' + item.ingredientId);
            tr.appendChild(tdName);

            var tdQty = document.createElement('td');
            var inputQty = document.createElement('input');
            inputQty.type = 'number';
            inputQty.className = 'form-control form-control-sm';
            inputQty.min = '0';
            inputQty.step = '0.01';
            inputQty.value = item.quantity != null ? item.quantity : 0;
            tdQty.appendChild(inputQty);
            tr.appendChild(tdQty);

            var tdUnit = document.createElement('td');
            var unitText = item.unit || '';
            var ingInfo = chefIngredients.find(function (i) { return i.id === item.ingredientId; });
            if (ingInfo && typeof ingInfo.stock === 'number') {
                unitText += ' (tồn: ' + ingInfo.stock + ' ' + (ingInfo.unit || '') + ')';
            }
            tdUnit.textContent = unitText;
            tr.appendChild(tdUnit);

            var tdRemove = document.createElement('td');
            var chk = document.createElement('input');
            chk.type = 'checkbox';
            chk.className = 'form-check-input';
            chk.checked = !!item.isRemoved;
            tdRemove.appendChild(chk);
            tr.appendChild(tdRemove);

            tbody.appendChild(tr);
        });
    }

    function saveOrderItemIngredients() {
        var orderItemId = currentOrderItemId || parseInt(document.getElementById('orderItemIdInput').value);
        if (!orderItemId || orderItemId <= 0) {
            alert('Món trong đơn không hợp lệ.');
            return;
        }

        var tbody = document.getElementById('orderItemIngredientsTableBody');
        if (!tbody) return;

        var rows = tbody.querySelectorAll('tr[data-ingredient-id]');
        if (!rows.length) {
            alert('Danh sách thành phần không hợp lệ.');
            return;
        }

        var items = [];
        rows.forEach(function (tr) {
            var ingredientId = parseInt(tr.getAttribute('data-ingredient-id') || '0');
            if (!ingredientId) return;

            var qtyInput = tr.querySelector('input[type="number"]');
            var removeChk = tr.querySelector('input[type="checkbox"]');
            var qty = qtyInput ? parseFloat(qtyInput.value.replace(',', '.')) : 0;
            if (isNaN(qty) || qty < 0) {
                qty = 0;
            }

            items.push({
                IngredientId: ingredientId,
                Quantity: qty,
                IsRemoved: removeChk ? removeChk.checked : false
            });
        });

        $.ajax({
            url: config.urls.saveOrderItemIngredients,
            type: 'POST',
            data: {
                orderItemId: orderItemId,
                itemsJson: JSON.stringify(items)
            }
        })
            .done(function (res) {
                if (res && res.success) {
                    alert(res.message || 'Đã lưu thành phần cho đơn này.');
                    var modalEl = document.getElementById('orderItemIngredientsModal');
                    var modal = bootstrap.Modal.getInstance(modalEl);
                    if (modal) modal.hide();
                } else {
                    alert(res && res.message ? res.message : 'Không lưu được thành phần.');
                }
            })
            .fail(function () {
                alert('Không kết nối được đến máy chủ.');
            });
    }

    function openIngredientStockModal() {
        var searchInput = document.getElementById('ingredientStockSearch');
        var chkLow = document.getElementById('onlyLowStock');
        if (searchInput) searchInput.value = '';
        if (chkLow) chkLow.checked = false;

        renderIngredientStockTable();

        var modal = new bootstrap.Modal(document.getElementById('ingredientStockModal'));
        modal.show();
    }

    function renderIngredientStockTable() {
        var tbody = document.getElementById('ingredientStockTableBody');
        if (!tbody) return;

        tbody.innerHTML = '';

        if (!Array.isArray(chefIngredients) || !chefIngredients.length) {
            var tr = document.createElement('tr');
            var td = document.createElement('td');
            td.colSpan = 4;
            td.className = 'text-center text-muted';
            td.textContent = 'Chưa có dữ liệu nguyên liệu.';
            tr.appendChild(td);
            tbody.appendChild(tr);
            return;
        }

        var search = (document.getElementById('ingredientStockSearch')?.value || '').toLowerCase();
        var onlyLow = document.getElementById('onlyLowStock')?.checked === true;

        var filtered = chefIngredients.filter(function (ing) {
            var nameMatch = !search || (ing.name || '').toLowerCase().indexOf(search) !== -1;
            var stockVal = typeof ing.stock === 'number' ? ing.stock : 0;
            var reorderVal = typeof ing.reorderLevel === 'number' ? ing.reorderLevel : 0;
            var isLow = reorderVal > 0 && stockVal <= reorderVal;
            var lowMatch = !onlyLow || isLow;
            return nameMatch && lowMatch;
        });

        if (!filtered.length) {
            var trEmpty = document.createElement('tr');
            var tdEmpty = document.createElement('td');
            tdEmpty.colSpan = 4;
            tdEmpty.className = 'text-center text-muted';
            tdEmpty.textContent = 'Không tìm thấy nguyên liệu phù hợp.';
            trEmpty.appendChild(tdEmpty);
            tbody.appendChild(trEmpty);
            return;
        }

        filtered.forEach(function (ing) {
            var tr = document.createElement('tr');

            var tdName = document.createElement('td');
            tdName.textContent = ing.name || '';
            tr.appendChild(tdName);

            var tdUnit = document.createElement('td');
            tdUnit.textContent = ing.unit || '';
            tr.appendChild(tdUnit);

            var stockVal = typeof ing.stock === 'number' ? ing.stock : 0;
            var tdStock = document.createElement('td');
            tdStock.textContent = stockVal + (ing.unit ? ' ' + ing.unit : '');
            tr.appendChild(tdStock);

            var reorderVal = typeof ing.reorderLevel === 'number' ? ing.reorderLevel : 0;
            var tdReorder = document.createElement('td');
            tdReorder.textContent = reorderVal + (ing.unit ? ' ' + ing.unit : '');
            tr.appendChild(tdReorder);

            if (reorderVal > 0 && stockVal <= reorderVal) {
                tr.classList.add('table-danger');
            }

            tbody.appendChild(tr);
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        renderMenuGrid();
        startChefBoardAutoRefresh();

        var dishImageFile = document.getElementById('dishImageFile');
        if (dishImageFile) {
            dishImageFile.addEventListener('change', function (e) {
                var input = e.target;
                if (input.files && input.files[0]) {
                    var reader = new FileReader();
                    reader.onload = function (ev) {
                        var img = document.getElementById('dishImagePreview');
                        if (img) img.src = ev.target.result;
                    };
                    reader.readAsDataURL(input.files[0]);
                }
            });
        }

        var ingredientSelect = document.getElementById('ingredientSelect');
        if (ingredientSelect && Array.isArray(chefIngredients)) {
            chefIngredients.forEach(function (ing) {
                var opt = document.createElement('option');
                opt.value = ing.id;
                var stockText = typeof ing.stock === 'number' ? (' (còn: ' + ing.stock + ' ' + (ing.unit || '')) : '';
                opt.textContent = ing.name + stockText;
                ingredientSelect.appendChild(opt);
            });

            ingredientSelect.addEventListener('change', function () {
                var selectedId = parseInt(this.value);
                var ing = chefIngredients.find(function (i) { return i.id === selectedId; });
                var label = document.getElementById('ingredientUnitLabel');
                if (ing) {
                    var stockText = typeof ing.stock === 'number' ? (' - tồn: ' + ing.stock + ' ' + (ing.unit || '')) : '';
                    label.textContent = (ing.unit || '--') + stockText;
                } else {
                    label.textContent = '--';
                }
            });
        }
    });

    window.addEventListener('beforeunload', function () {
        if (chefBoardRefreshTimer) {
            clearInterval(chefBoardRefreshTimer);
            chefBoardRefreshTimer = null;
        }
    });

    window.refreshOrdersBoard = refreshOrdersBoard;
    window.startChefBoardAutoRefresh = startChefBoardAutoRefresh;
    window.updateStatus = updateStatus;
    window.openCancelOrderModal = openCancelOrderModal;
    window.confirmCancelOrder = confirmCancelOrder;
    window.setDishAvailability = setDishAvailability;
    window.submitAddDish = submitAddDish;
    window.handleLogout = handleLogout;
    window.resetAddDishForm = resetAddDishForm;
    window.openEditDishModal = openEditDishModal;
    window.submitEditDish = submitEditDish;
    window.renderMenuGrid = renderMenuGrid;
    window.openDishIngredients = openDishIngredients;
    window.renderDishIngredientsTable = renderDishIngredientsTable;
    window.saveDishIngredient = saveDishIngredient;
    window.removeDishIngredient = removeDishIngredient;
    window.openOrderItemIngredients = openOrderItemIngredients;
    window.renderOrderItemIngredientsTable = renderOrderItemIngredientsTable;
    window.saveOrderItemIngredients = saveOrderItemIngredients;
    window.openIngredientStockModal = openIngredientStockModal;
    window.renderIngredientStockTable = renderIngredientStockTable;
})();

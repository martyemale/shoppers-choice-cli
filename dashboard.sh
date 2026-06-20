#!/bin/bash
DATA_DIR="$HOME/shoppers-choice-cli/data"
INVENTORY_FILE="$DATA_DIR/inventory.csv"
MOVEMENTS_FILE="$DATA_DIR/movements.csv"
EXPENSE_FILE="$DATA_DIR/expenses.csv"
DASHBOARD="$HOME/shoppers-choice-cli/dashboard.html"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)
TIMESTAMP=$(date '+%B %d, %Y at %I:%M %p')

TOTAL_PRODUCTS=$(tail -n +2 "$INVENTORY_FILE" 2>/dev/null | wc -l | tr -d ' ')
SALES_TODAY=$(grep "$TODAY.*SALE" "$MOVEMENTS_FILE" 2>/dev/null | wc -l | tr -d ' ')
LOW_STOCK=0
TOTAL_VALUE=0
TOTAL_EXPENSES=0

while IFS=, read -r sku name cat cost price qty reorder; do
    TOTAL_VALUE=$((TOTAL_VALUE + qty * cost))
    if [ "$qty" -le "$reorder" ] 2>/dev/null; then
        LOW_STOCK=$((LOW_STOCK + 1))
    fi
done < <(tail -n +2 "$INVENTORY_FILE" 2>/dev/null)

while IFS=, read -r date cat desc amount by; do
    if echo "$date" | grep -q "$MONTH"; then
        TOTAL_EXPENSES=$((TOTAL_EXPENSES + amount))
    fi
done < <(tail -n +2 "$EXPENSE_FILE" 2>/dev/null)

INVENTORY_ROWS=""
while IFS=, read -r sku name cat cost price qty reorder; do
    if [ "$qty" -le "$reorder" ] 2>/dev/null; then
        SC="qty-low"; ST="LOW"
    else
        SC="qty-ok"; ST="OK"
    fi
    INVENTORY_ROWS="${INVENTORY_ROWS}<tr><td>${sku}</td><td>${name}</td><td>${cat}</td><td>${cost}</td><td>${price}</td><td class=${SC}>${qty}</td><td>${reorder}</td><td class=${SC}>${ST}</td></tr>"
done < <(tail -n +2 "$INVENTORY_FILE" 2>/dev/null)

MOVEMENT_ROWS=""
while IFS=, read -r date sku type qty prev new by notes; do
    MOVEMENT_ROWS="${MOVEMENT_ROWS}<tr><td>${date}</td><td>${sku}</td><td>${type}</td><td>${qty}</td><td>${prev}</td><td>${new}</td><td>${by}</td></tr>"
done < <(tail -n +2 "$MOVEMENTS_FILE" 2>/dev/null | tail -20)

EXPENSE_ROWS=""
while IFS=, read -r date cat desc amount by; do
    EXPENSE_ROWS="${EXPENSE_ROWS}<tr><td>${date}</td><td>${cat}</td><td>${desc}</td><td>NGN ${amount}</td><td>${by}</td></tr>"
done < <(tail -n +2 "$EXPENSE_FILE" 2>/dev/null | tail -20)

echo "<!DOCTYPE html><html><head><meta charset=UTF-8><meta name=viewport content='width=device-width,initial-scale=1.0'><title>Shopper's Choice</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:#0a0f1c;color:#e0e6f0;padding:20px}.header{text-align:center;padding:30px 0;border-bottom:2px solid #1a2340;margin-bottom:30px}.header h1{font-size:28px;color:#fff;letter-spacing:2px}.header .sub{color:#4a9eff;font-size:14px}.header .ts{color:#667799;font-size:12px;margin-top:8px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px;margin-bottom:30px}.card{background:#111827;border:1px solid #1f2937;border-radius:12px;padding:20px;text-align:center}.card .l{font-size:11px;color:#667799;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px}.card .v{font-size:26px;font-weight:700}.green{color:#34d399}.red{color:#f87171}.blue{color:#60a5fa}.amber{color:#fbbf24}.sec{background:#111827;border:1px solid #1f2937;border-radius:12px;padding:24px;margin-bottom:24px}.sec h2{font-size:15px;color:#4a9eff;text-transform:uppercase;letter-spacing:1px;margin-bottom:16px;padding-bottom:8px;border-bottom:1px solid #1f2937}table{width:100%;border-collapse:collapse}th{text-align:left;padding:10px;font-size:11px;color:#667799;text-transform:uppercase;border-bottom:1px solid #1f2937}td{padding:10px;font-size:14px;border-bottom:1px solid #0d1321}tr:hover{background:#0d1525}.qty-low{color:#f87171;font-weight:700}.qty-ok{color:#34d399;font-weight:700}.foot{text-align:center;padding:20px;color:#334155;font-size:12px}</style></head><body><div class=header><h1>SHOPPER'S CHOICE</h1><div class=sub>Distribution Management Dashboard</div><div class=ts>Generated: ${TIMESTAMP}</div></div><div class=grid><div class=card><div class=l>Products</div><div class='v blue'>${TOTAL_PRODUCTS}</div></div><div class=card><div class=l>Inventory Value</div><div class='v green'>NGN ${TOTAL_VALUE}</div></div><div class=card><div class=l>Sales Today</div><div class='v amber'>${SALES_TODAY}</div></div><div class=card><div class=l>Low Stock</div><div class='v red'>${LOW_STOCK}</div></div><div class=card><div class=l>Monthly Expenses</div><div class='v red'>NGN ${TOTAL_EXPENSES}</div></div></div><div class=sec><h2>Inventory</h2><table><thead><tr><th>SKU</th><th>Name</th><th>Category</th><th>Cost</th><th>Price</th><th>Qty</th><th>Reorder</th><th>Status</th></tr></thead><tbody>${INVENTORY_ROWS}</tbody></table></div><div class=sec><h2>Expenses This Month</h2><table><thead><tr><th>Date</th><th>Category</th><th>Description</th><th>Amount</th><th>By</th></tr></thead><tbody>${EXPENSE_ROWS}</tbody></table></div><div class=sec><h2>Recent Activity</h2><table><thead><tr><th>Date</th><th>SKU</th><th>Type</th><th>Qty</th><th>Before</th><th>After</th><th>By</th></tr></thead><tbody>${MOVEMENT_ROWS}</tbody></table></div><div class=foot>Shopper's Choice Distribution Management System</div></body></html>" > "$DASHBOARD"

echo "Dashboard generated: $DASHBOARD"
echo "Opening in browser..."
open "$DASHBOARD" 2>/dev/null || echo "Open $DASHBOARD in your browser"

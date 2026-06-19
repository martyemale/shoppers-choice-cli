#!/bin/bash
DATA_DIR="$HOME/shoppers-choice-cli/data"
INVENTORY_FILE="$DATA_DIR/inventory.csv"
MOVEMENTS_FILE="$DATA_DIR/movements.csv"

mkdir -p "$DATA_DIR"

if [ ! -f "$INVENTORY_FILE" ]; then
    echo "SKU,Name,Category,Unit_Cost,Selling_Price,Quantity,Reorder_Level" > "$INVENTORY_FILE"
fi

if [ ! -f "$MOVEMENTS_FILE" ]; then
    echo "Date,SKU,Type,Quantity,Previous_Qty,New_Qty,Performed_By,Notes" > "$MOVEMENTS_FILE"
fi

add_product() {
    read -p "SKU (e.g. SC-001): " sku
    if grep -q "^$sku," "$INVENTORY_FILE"; then
        echo "  ERROR: SKU $sku already exists."
        return
    fi
    read -p "Product Name: " name
    read -p "Category: " category
    read -p "Unit Cost (NGN): " cost
    read -p "Selling Price (NGN): " price
    read -p "Initial Quantity: " qty
    read -p "Reorder Level: " reorder
    echo "$sku,$name,$category,$cost,$price,$qty,$reorder" >> "$INVENTORY_FILE"
    echo "$(date +%Y-%m-%d_%H:%M),$sku,INITIAL,$qty,0,$qty,$(whoami),Product added" >> "$MOVEMENTS_FILE"
    echo ""
    echo "  Product added: $name ($sku) - Qty: $qty - Price: NGN $price"
}

view_inventory() {
    echo ""
    echo "  CURRENT INVENTORY"
    echo "  ========================================="
    echo ""
    if [ $(wc -l < "$INVENTORY_FILE") -le 1 ]; then
        echo "  No products in inventory."
        return
    fi
    printf "  %-10s %-20s %-10s %-10s %-10s %-8s\n" "SKU" "Name" "Category" "Cost" "Price" "Qty"
    echo "  --------------------------------------------------------------------------"
    tail -n +2 "$INVENTORY_FILE" | while IFS=, read -r sku name cat cost price qty reorder; do
        printf "  %-10s %-20s %-10s NGN %-6s NGN %-6s %-8s\n" "$sku" "$name" "$cat" "$cost" "$price" "$qty"
    done
}

record_sale() {
    read -p "Product SKU: " sku
    line=$(grep "^$sku," "$INVENTORY_FILE")
    if [ -z "$line" ]; then
        echo "  ERROR: SKU $sku not found."
        return
    fi
    current_qty=$(echo "$line" | cut -d',' -f6)
    product_name=$(echo "$line" | cut -d',' -f2)
    selling_price=$(echo "$line" | cut -d',' -f5)
    echo "  Product: $product_name | Available: $current_qty | Price: NGN $selling_price"
    read -p "Quantity to sell: " sell_qty
    if [ "$sell_qty" -gt "$current_qty" ]; then
        echo "  ERROR: Insufficient stock. Only $current_qty available."
        return
    fi
    new_qty=$((current_qty - sell_qty))
    total=$((sell_qty * selling_price))
    sed -i '' "s/^$sku,\(.*\),$current_qty,\(.*\)/$sku,\1,$new_qty,\2/" "$INVENTORY_FILE"
    echo "$(date +%Y-%m-%d_%H:%M),$sku,SALE,$sell_qty,$current_qty,$new_qty,$(whoami),Sold $sell_qty units" >> "$MOVEMENTS_FILE"
    echo ""
    echo "  SALE RECORDED"
    echo "  Product:  $product_name"
    echo "  Quantity: $sell_qty"
    echo "  Total:    NGN $total"
    echo "  Stock:    $current_qty -> $new_qty"
}

receive_stock() {
    read -p "Product SKU: " sku
    line=$(grep "^$sku," "$INVENTORY_FILE")
    if [ -z "$line" ]; then
        echo "  ERROR: SKU $sku not found."
        return
    fi
    current_qty=$(echo "$line" | cut -d',' -f6)
    product_name=$(echo "$line" | cut -d',' -f2)
    echo "  Product: $product_name | Current Stock: $current_qty"
    read -p "Quantity received: " recv_qty
    new_qty=$((current_qty + recv_qty))
    sed -i '' "s/^$sku,\(.*\),$current_qty,\(.*\)/$sku,\1,$new_qty,\2/" "$INVENTORY_FILE"
    echo "$(date +%Y-%m-%d_%H:%M),$sku,PURCHASE,$recv_qty,$current_qty,$new_qty,$(whoami),Received stock" >> "$MOVEMENTS_FILE"
    echo ""
    echo "  STOCK RECEIVED"
    echo "  Product:  $product_name"
    echo "  Added:    $recv_qty"
    echo "  Stock:    $current_qty -> $new_qty"
}

low_stock_check() {
    echo ""
    echo "  LOW STOCK ALERTS"
    echo "  ========================================="
    found=0
    tail -n +2 "$INVENTORY_FILE" | while IFS=, read -r sku name cat cost price qty reorder; do
        if [ "$qty" -le "$reorder" ]; then
            echo "  WARNING: $name ($sku) - Qty: $qty (Reorder at: $reorder)"
            found=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "  All stock levels healthy."
    fi
}

view_movements() {
    echo ""
    echo "  INVENTORY MOVEMENT LOG"
    echo "  ========================================="
    echo ""
    printf "  %-18s %-10s %-10s %-6s %-6s %-6s\n" "Date" "SKU" "Type" "Qty" "From" "To"
    echo "  ----------------------------------------------------------"
    tail -n +2 "$MOVEMENTS_FILE" | tail -20 | while IFS=, read -r date sku type qty prev new by notes; do
        printf "  %-18s %-10s %-10s %-6s %-6s %-6s\n" "$date" "$sku" "$type" "$qty" "$prev" "$new"
    done
}

daily_summary() {
    today=$(date +%Y-%m-%d)
    echo ""
    echo "  DAILY SUMMARY - $today"
    echo "  ========================================="
    sales_count=$(grep "$today.*SALE" "$MOVEMENTS_FILE" 2>/dev/null | wc -l | tr -d ' ')
    purchases_count=$(grep "$today.*PURCHASE" "$MOVEMENTS_FILE" 2>/dev/null | wc -l | tr -d ' ')
    total_products=$(tail -n +2 "$INVENTORY_FILE" | wc -l | tr -d ' ')
    total_value=0
    while IFS=, read -r sku name cat cost price qty reorder; do
        line_value=$((qty * cost))
        total_value=$((total_value + line_value))
    done < <(tail -n +2 "$INVENTORY_FILE")
    echo "  Total Products:    $total_products"
    echo "  Sales Today:       $sales_count"
    echo "  Receipts Today:    $purchases_count"
    echo "  Inventory Value:   NGN $total_value"
}

while true; do
    echo ""
    echo "  ======================================"
    echo "    SHOPPER'S CHOICE"
    echo "    Inventory Management System"
    echo "  ======================================"
    echo "  1) View Inventory"
    echo "  2) Add Product"
    echo "  3) Record Sale"
    echo "  4) Receive Stock"
    echo "  5) Low Stock Check"
    echo "  6) Movement Log"
    echo "  7) Daily Summary"
    echo "  8) Exit"
    echo "  ======================================"
    read -p "  Select: " choice
    case $choice in
        1) view_inventory ;;
        2) add_product ;;
        3) record_sale ;;
        4) receive_stock ;;
        5) low_stock_check ;;
        6) view_movements ;;
        7) daily_summary ;;
        8) echo "  Goodbye."; exit 0 ;;
        *) echo "  Invalid option." ;;
    esac
done

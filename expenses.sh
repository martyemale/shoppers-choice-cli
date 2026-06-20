#!/bin/bash
DATA_DIR="$HOME/shoppers-choice-cli/data"
EXPENSE_FILE="$DATA_DIR/expenses.csv"

mkdir -p "$DATA_DIR"

if [ ! -f "$EXPENSE_FILE" ]; then
    echo "Date,Category,Description,Amount,Recorded_By" > "$EXPENSE_FILE"
fi

add_expense() {
    echo ""
    echo "  Categories: rent, transport, salary, utilities, supplies, other"
    read -p "  Category: " category
    read -p "  Description: " description
    read -p "  Amount (NGN): " amount
    TODAY=$(date +%Y-%m-%d)
    echo "$TODAY,$category,$description,$amount,$(whoami)" >> "$EXPENSE_FILE"
    echo ""
    echo "  EXPENSE RECORDED"
    echo "  Date:     $TODAY"
    echo "  Category: $category"
    echo "  Amount:   NGN $amount"
}

view_expenses() {
    echo ""
    echo "  EXPENSE LOG"
    echo "  ========================================="
    if [ $(wc -l < "$EXPENSE_FILE") -le 1 ]; then
        echo "  No expenses recorded."
        return
    fi
    printf "  %-12s %-12s %-20s %-12s\n" "Date" "Category" "Description" "Amount"
    echo "  -------------------------------------------------------"
    tail -n +2 "$EXPENSE_FILE" | while IFS=, read -r date cat desc amount by; do
        printf "  %-12s %-12s %-20s NGN %-8s\n" "$date" "$cat" "$desc" "$amount"
    done
}

expense_summary() {
    echo ""
    echo "  EXPENSE SUMMARY"
    echo "  ========================================="
    total=0
    for cat in rent transport salary utilities supplies other; do
        cat_total=0
        while IFS=, read -r date category desc amount by; do
            if [ "$category" = "$cat" ]; then
                cat_total=$((cat_total + amount))
            fi
        done < <(tail -n +2 "$EXPENSE_FILE" 2>/dev/null)
        if [ "$cat_total" -gt 0 ]; then
            printf "  %-15s NGN %s\n" "$cat" "$cat_total"
            total=$((total + cat_total))
        fi
    done
    echo "  ========================================="
    printf "  %-15s NGN %s\n" "TOTAL" "$total"
}

monthly_report() {
    MONTH=$(date +%Y-%m)
    echo ""
    echo "  MONTHLY EXPENSES - $MONTH"
    echo "  ========================================="
    total=0
    tail -n +2 "$EXPENSE_FILE" 2>/dev/null | while IFS=, read -r date cat desc amount by; do
        if echo "$date" | grep -q "$MONTH"; then
            printf "  %-12s %-12s %-20s NGN %-8s\n" "$date" "$cat" "$desc" "$amount"
            total=$((total + amount))
        fi
    done
    echo "  ========================================="
}

while true; do
    echo ""
    echo "  ======================================"
    echo "    SHOPPER'S CHOICE"
    echo "    Expense Tracker"
    echo "  ======================================"
    echo "  1) Add Expense"
    echo "  2) View All Expenses"
    echo "  3) Expense Summary by Category"
    echo "  4) This Month's Expenses"
    echo "  5) Exit"
    echo "  ======================================"
    read -p "  Select: " choice
    case $choice in
        1) add_expense ;;
        2) view_expenses ;;
        3) expense_summary ;;
        4) monthly_report ;;
        5) echo "  Goodbye."; exit 0 ;;
        *) echo "  Invalid option." ;;
    esac
done

#!/bin/bash
# Monitor the progress of the weekly summary creation

echo "Monitoring weekly summary creation..."
echo "Press Ctrl+C to stop monitoring (script will continue running)"
echo ""

while true; do
    clear
    echo "=========================================="
    echo "WEEKLY SUMMARY CREATION - PROGRESS"
    echo "=========================================="
    echo ""
    
    # Check if process is running
    if ps aux | grep -v grep | grep "create_weekly_summary" > /dev/null; then
        echo "✅ Script is RUNNING"
    else
        echo "⚠️  Script is NOT running"
    fi
    
    echo ""
    echo "Last 30 lines of log:"
    echo "------------------------------------------"
    tail -30 summary_creation_log.txt 2>/dev/null || echo "No log yet..."
    echo "------------------------------------------"
    
    sleep 5
done


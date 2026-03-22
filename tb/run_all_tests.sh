#!/bin/bash
set -e
cd "$(dirname "$0")"

FAILED_TESTS=0

for tb in tb_baud_gen.v tb_piso.v tb_sipo.v tb_parity_gen.v tb_sampler.v tb_tx.v tb_rx.v tb_rx_recovery.v tb_uart_top.v tb_loopback_test.v; do
  echo "--- Testing $tb ---"
  
  # Compile
  if ! iverilog -g2012 -I ../src -o tb.vvp ../src/*.v "$tb"; then
    echo "ERROR: Compile failed for $tb"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    continue
  fi
  
  # Run and capture output
  OUTPUT=$(vvp tb.vvp)
  echo "$OUTPUT"
  
  # Check for custom error strings
  if echo "$OUTPUT" | grep -qE "ERROR|FAIL|FATAL"; then
    echo ">>> $tb FAILED!"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  else
    echo ">>> $tb PASSED!"
  fi
  echo ""
done

if [ "$FAILED_TESTS" -ne 0 ]; then
  echo "Overall Status: FAILED ($FAILED_TESTS testbenches had errors)"
  exit 1
else
  echo "Overall Status: PASSED (All testbenches passed successfully)"
  exit 0
fi

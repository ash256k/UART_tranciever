# UART Transceiver

A robust, configurable UART transceiver implemented in Verilog-2001.

## Features
- **Configurable Parameters**: Baud rate, clock frequency, data size (default 8), stop bits (1/2), parity (NONE/EVEN/ODD).
- **Oversampling**: 16x oversampling for noise immunity.
- **Robustness**: 
  - 3-stage synchronizers on inputs.
  - Majority voting sample logic.
  - False Start Bit recovery (glitch rejection < 8 ticks).
- **Error Detection**: Parity error and Frame error reporting aligned with datavalid signal.

## Directory Structure
- `src/`: RTL source code.
  - `uart.v`: Top-level module.
  - `rx.v`: Receiver core with Finite State Machine.
  - `tx.v`: Transmitter core.
  - `baud_gen.v`: Tick generator.
  - `sampler.v`: Input synchronization and sampling logic.
- `tb/`: Testbenches.
  - `tb_uart_top.v`: System-level loopback verification.
  - `tb_rx_recovery.v`: False-start recovery test.
  - `tb_*.v`: Unit tests for submodules.
- `fpga/`: Renesas ForgeFPGA specific wrappers.

## Simulation
Verified using Icarus Verilog (`iverilog`).

### Run System Verification
```bash
cd tb
iverilog -o sim.out -I ../src ../src/*.v tb_uart_top.v
vvp sim.out
```

### Run Unit Tests
Example for Baud Generator:
```bash
iverilog -o baud.out -I ../src ../src/baud_gen.v tb_baud_gen.v
vvp baud.out
```

## Interface (`uart.v`)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `i_clk` | Input | System Clock (default 50MHz) |
| `i_rst_n` | Input | Active-Low Asynchronous Reset |
| `i_rx_line` | Input | Serial RX Line |
| `i_rx_en` | Input | Receiver Enable |
| `o_rx_data` | Output | Received Data Byte |
| `o_rx_done` | Output | Data Valid Pulse (1 cycle) |
| `o_rx_err...` | Output | Frame/Parity Error Flags (Valid when done=1) |
| `i_tx_data` | Input | Data to Transmit |
| `i_tx_en` | Input | Transmit Trigger |
| `o_tx_line` | Output | Serial TX Line |
| `o_tx_busy` | Output | Transmitter Busy Flag |

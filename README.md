# 🏧 ATM Machine — Edge Artix 7 FPGA (Verilog)

A hardware implementation of a basic ATM (Automated Teller Machine) system,
designed and verified on the **Edge Artix 7 FPGA development board** using Verilog HDL.

---

## 📌 Project Overview

This project simulates the core functionality of an ATM machine on an FPGA.
It handles user input through physical push buttons (with hardware debouncing),
processes ATM logic in a top-level finite state machine, and displays information
on the onboard 7-segment displays.

---

## 🗂️ File Structure
atm-artix7-fpga/
├── src/
│   ├── atm_top.v          # Top-level ATM controller (FSM + PIN/balance logic)
│   ├── button_debounce.v  # Button debounce circuit for stable input
│   └── sevenseg_mux.v     # 7-segment display multiplexer for multi-digit output
├── constraints/
│   └── atm_constraints.xdc  # Pin mapping for Edge Artix 7 board
└── README.md
---

## 🧩 Module Descriptions

### `atm_top.v` — Top-Level Module
The main controller of the ATM system. Implements a **Finite State Machine (FSM)**
that manages the following states:
- **IDLE** — Waiting for user input
- **PIN ENTRY** — Accept PIN digits from the user
- **PIN VERIFY** — Validate the entered PIN
- **MENU** — Show options (Check Balance / Withdraw / Exit)
- **WITHDRAW** — Process withdrawal and update balance
- **ERROR / LOCKED** — Handle incorrect PIN attempts

**Inputs:** Clock, Reset, Button inputs (debounced)
**Outputs:** 7-segment display data, LEDs for status indication

---

### `button_debounce.v` — Button Debounce Circuit
Physical push buttons produce noisy signals when pressed. This module filters
out glitches using a **counter-based debounce technique**, ensuring a clean
single pulse is sent to the main logic for every button press.

**Inputs:** `clk`, `btn_in`
**Output:** `btn_out` (debounced, stable signal)

---

### `sevenseg_mux.v` — 7-Segment Display Multiplexer
Drives multiple 7-segment display digits using **time-division multiplexing (TDM)**.
Rapidly cycles through each digit at high frequency, giving the appearance of all
digits being lit simultaneously.

**Inputs:** `clk`, digit values (BCD or binary)
**Outputs:** `seg[6:0]` (segment lines), `an[3:0]` (anode select)

---

## 🛠️ Tools & Technologies

| Tool | Purpose |
|------|---------|
| **Xilinx Vivado** | Synthesis, Implementation, Bitstream Generation |
| **Verilog HDL** | Hardware Description Language |
| **Edge Artix 7 Board** | Target FPGA hardware (XC7A35T) |
| **Vivado Simulator** | Functional & Timing Simulation |

---

## 🚀 How to Run

### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/atm-artix7-fpga.git
cd atm-artix7-fpga
```

### 2. Open in Vivado
- Launch **Xilinx Vivado**
- Create a new project and add all `.v` files from `src/` as design sources
- Add the `.xdc` file from `constraints/` as a constraint source
- Set target part to **xc7a35tcpg236-1** (Edge Artix 7)

### 3. Synthesize & Implement
- Run Synthesis → Run Implementation → Generate Bitstream

### 4. Program the Board
- Connect board via USB → Open Hardware Manager → Auto Connect
- Click **Program Device** and select the `.bit` file

---

## 🔌 Pin Mapping (Edge Artix 7)

| Signal     | Board Pin | Description              |
|------------|-----------|--------------------------|
| `clk`      | W5        | 100 MHz onboard clock    |
| `reset`    | U18       | Center push button       |
| `btn[0]`   | T18       | Confirm / digit input    |
| `btn[1]`   | W19       | Increment value          |
| `btn[2]`   | T17       | Select option            |
| `seg[6:0]` | W7–W6...  | 7-segment cathodes       |
| `an[3:0]`  | U2–U7...  | 7-segment anodes         |
| `led[3:0]` | U16...    | Status LEDs              |

> ⚠️ Verify and update pin assignments in the `.xdc` file to match your board.

---

## 📷 Demo

> *(Add a photo or short video of the working board here)*

---

## 📄 License

This project is open source under the [MIT License](LICENSE).

---

## 👤 Author

**Your Name**
B.Tech ECE / EEE — *Your College Name*
GitHub: [@YOUR_USERNAME](https://github.com/YOUR_USERNAME)

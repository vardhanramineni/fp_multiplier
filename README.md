# 32-bit IEEE-754 Floating-Point Multiplier — Radix-4 Booth + Dadda Tree

A fully synthesizable, structural Verilog-2005 implementation of a single-precision
IEEE-754 floating-point multiplier targeting the **Xilinx Artix-7 FPGA (xc7a100tcsg324-1)**.
The design focuses on optimizing the mantissa multiplication datapath using
**Radix-4 Modified Booth Encoding** and a **Bounded Dadda Reduction Tree**,
achieving significant area and delay reduction over conventional array multipliers.

---

## Block Diagram

## Project Architecture

<p align="center">
  <img src="images/Copy of fpmul32.jpg.jpeg" width="800">
</p>

---

## Table of Contents

- [Features](#features)
- [IEEE-754 Single-Precision Format](#ieee-754-single-precision-format)
- [Architecture Overview](#architecture-overview)
  - [Sign Block](#1-sign-block)
  - [Exponent Adder](#2-exponent-adder)
  - [Mantissa Multiplier](#3-mantissa-multiplier)
    - [Radix-4 Booth Encoder](#31-radix-4-booth-encoder)
    - [Partial Product Generator](#32-partial-product-generator)
    - [PP Alignment and Sign Correction](#33-pp-alignment-and-sign-correction)
    - [Dadda Reduction Tree](#34-dadda-reduction-tree)
    - [Carry Propagate Adder](#35-carry-propagate-adder)
  - [Normalization Block](#4-normalization-block)
  - [Rounding Block](#5-rounding-block)
  - [Special Case Handler](#6-special-case-handler)
- [File Structure](#file-structure)
- [Simulation](#simulation)
- [Synthesis Results](#synthesis-results)
- [Test Case Walkthrough](#test-case-walkthrough)
- [Tools Used](#tools-used)

---

## Features

- Full IEEE-754 single-precision (binary32) compliant multiplication
- Purely combinational, single-cycle datapath — no pipeline registers
- Radix-4 Modified Booth Encoding reduces 24 partial products to **13**
- Bounded Dadda reduction tree constrained to **52-bit** datapath (41% narrower than conventional 88-bit designs)
- Narrow 25-bit Partial Product Generator — eliminates redundant sign extensions
- Wire-routed two-shift stage — zero-logic shift operation using hardwired concatenation
- IEEE-754 special case handling: Zero, Infinity, NaN, Inf × Zero
- Round-to-Nearest-Even rounding with guard, round, and sticky bits
- Structural Verilog-2005 throughout — no behavioral `*` operator in the datapath
- Verified on Xilinx Vivado 2023.2 targeting xc7a100tcsg324-1

---

## IEEE-754 Single-Precision Format

```
 31  30        23  22                    0
 ┌───┬──────────┬──────────────────────────┐
 │ S │ Exponent │        Mantissa          │
 │1 b│   8 bits │        23 bits           │
 └───┴──────────┴──────────────────────────┘
```

| Field    | Width | Description                          |
|----------|-------|--------------------------------------|
| Sign (S) | 1 bit | 0 = positive, 1 = negative           |
| Exponent | 8 bit | Biased by 127 (bias = 127)           |
| Mantissa | 23 bit| Fractional part (implicit leading 1) |

Mathematical value: `(−1)^S × (1.M) × 2^(E − 127)`

The implicit leading `1` makes the true mantissa width **24 bits**.

---

## Architecture Overview

> _Add detailed pipeline diagram here_

The multiplier executes three parallel operations:

```
P_sign     =  SA  XOR  SB
E_out      =  EA  +  EB  −  127
P_mantissa =  (1.MA)  ×  (1.MB)          →  48-bit product
```

The 48-bit mantissa product then passes through normalization and rounding to
produce the final 32-bit IEEE-754 result.

---

### 1. Sign Block

**Module:** `sign_block.v`

Simple XOR of the two sign bits:

```
S_out = S_A ⊕ S_B
```

Positive × Positive = Positive, Negative × Negative = Positive,
and mixed signs produce a Negative result.

---

### 2. Exponent Adder

**Module:** `exponent_adder.v`  
**Sub-modules:** `ripple_carry_adder_8bit.v`, `ripple_carry_subtractor_8bit.v`

Since both exponents carry the bias of 127, adding them produces a double-biased
result. One bias is subtracted to normalize:

```
E_out = E_A + E_B − 127
```

Implemented using an 8-bit ripple carry adder followed by an 8-bit subtractor.

---

### 3. Mantissa Multiplier

**Module:** `mantissa_multiplier.v`

This is the critical datapath. The 24-bit unsigned mantissas (implicit leading 1
prepended to the 23-bit fractional field) are multiplied to produce a 48-bit
unsigned product. The architecture has five stages:

> _Add mantissa multiplier block diagram here_

---

#### 3.1 Radix-4 Booth Encoder

**Module:** `booth_encoder.v`

The multiplier operand B is zero-extended to 25 bits and then to 27 bits (`B_ext`)
to ensure correct grouping and sign handling. This creates **13 overlapping 3-bit
Booth groups**.

Each group `{B_ext[2i+1], B_ext[2i], B_ext[2i−1]}` is encoded using the formula:

```
value = −2·B_ext[2i+1]  +  B_ext[2i]  +  B_ext[2i−1]
```

This maps every 3-bit pattern to one of five signed multiples: `{0, +a, −a, +2a, −2a}`.
The critical advantage is that `±3a` — which would require a costly pre-addition —
never appears.

**Encoding table:**

| B[2i+1] | B[2i] | B[2i−1] | Value | Multiple | Hardware          |
|---------|-------|---------|-------|----------|-------------------|
| 0       | 0     | 0       | 0     | 0        | output zero       |
| 0       | 0     | 1       | +1    | +a       | pass through      |
| 0       | 1     | 0       | +1    | +a       | pass through      |
| 0       | 1     | 1       | +2    | +2a      | left shift by 1   |
| 1       | 0     | 0       | −2    | −2a      | shift + negate    |
| 1       | 0     | 1       | −1    | −a       | negate            |
| 1       | 1     | 0       | −1    | −a       | negate            |
| 1       | 1     | 1       | 0     | 0        | output zero       |

The encoder outputs three control signals:

```verilog
neg  =  B_ext[2i+1] & ~(B_ext[2i] & B_ext[2i−1])
two  =  (B_ext[2i+1] ^ B_ext[2i]) & (B_ext[2i+1] ^ B_ext[2i−1])
non0 =  (B_ext[2i+1] ^ B_ext[2i]) | (B_ext[2i] ^ B_ext[2i−1])
```

> _Add Booth encoder RTL schematic here_

---

#### 3.2 Partial Product Generator

**Module:** `pp_generator.v`

Each of the 13 PPG units operates on a **25-bit datapath only** — the narrow-width
design eliminates redundant sign extensions that conventional wide-bus designs carry
through the entire tree.

The PPG uses a 2:1 multiplexer controlled by `two` to select between `A` and `2A`,
and `neg` to determine whether selective complementation is applied:

- `non0 = 0` → output zero (no partial product)
- `non0 = 1, two = 0` → output `±A`
- `non0 = 1, two = 1` → output `±2A`

The `±2A` case is handled in the next stage by wire-routing rather than a barrel
shifter, saving logic entirely.

> _Add PPG circuit diagram here_

---

#### 3.3 PP Alignment and Sign Correction

Each 25-bit raw partial product is expanded to 26 bits in the **Two-Shift stage**
through hardwired concatenation — zero logic, zero gates:

- When `two = 0` (±A): sign-extend by 1 bit
- When `two = 1` (±2A): shift left by 1, insert `neg` at LSB (1's complement for −2A)

```verilog
pp_wide = {pp_raw, enc_neg}   // when two = 1
```

The 26-bit partial products are then sign-extended and structurally aligned in a
**52-bit bus** based on their radix-4 weights (shift of 2 bits per row).
Maximum shift = 24 bits → maximum width = 26 + 24 = 50 bits, padded to 52 bits
with 2 guard bits to absorb cascaded carry growth.

A **sign-correction row** is added to account for the two's complement property
of negated Booth partial products, giving **14 rows** in total entering the Dadda tree.

> _Add partial product alignment dot diagram here_

---

#### 3.4 Dadda Reduction Tree

**Module:** `dadda_reduce.v`

The Dadda tree reduces 14 rows of 52-bit vectors down to 2 rows (Sum + Carry)
using the minimum number of full adders and half adders, compressing only those
columns that exceed the stage height limit.

The Dadda height sequence for 14 initial rows:

```
14  →  9  →  6  →  4  →  3  →  2
```

Five compression stages:

| Stage | Target height | Method                            |
|-------|--------------|-----------------------------------|
| 1     | ≤ 9          | FA compress columns > 9           |
| 2     | ≤ 6          | FA compress columns > 6           |
| 3     | ≤ 4          | FA compress columns > 4           |
| 4     | ≤ 3          | FA/HA compress columns > 3        |
| 5     | = 2          | Final sum and carry vectors       |

The tree is built entirely from `full_adder` and `half_adder` primitives using
`generate`/`genvar` loops — fully structural, Vivado-synthesizable.

> _Add Dadda dot diagram (5-stage compression) here_

---

#### 3.5 Carry Propagate Adder

**Module:** `ripple_carry_adder_n.v` (parameterized, WIDTH = 52)

The terminal Sum and Carry vectors from the Dadda tree are added by a
**52-bit Ripple Carry Adder**. Although theoretically O(N) delay, the
Artix-7 CARRY4 fast-carry primitives embedded in each logic slice make the
actual propagation delay small enough that Carry-Lookahead structures are
not required.

The lower **48 bits** of the CPA output form the unsigned mantissa product:

```
P[47:0] = (1.MA) × (1.MB)
```

---

### 4. Normalization Block

**Module:** `normalization_block.v`

The 48-bit product has the format `XX.YYYY...`. Two cases:

| Condition     | Action                                       |
|---------------|----------------------------------------------|
| Bit[47] = 1  | Already normalized — extract bits [46:24]    |
| Bit[47] = 0  | Shift left by 1 — extract bits [45:23], increment E_out |

---

### 5. Rounding Block

**Module:** `fp_rounding.v`

Implements **Round-to-Nearest-Even (RNE)** using three bits beyond the
kept mantissa:

| Bit     | Description                             |
|---------|-----------------------------------------|
| Guard   | First bit after the kept mantissa       |
| Round   | Second bit after the kept mantissa      |
| Sticky  | OR of all remaining bits                |

Round-up condition:
```
round_up = guard & (round | sticky | LSB_of_kept_mantissa)
```

---

### 6. Special Case Handler

**Module:** `special_case_handler.v`

Detects and handles all IEEE-754 mandatory special cases before the normal
datapath result is used:

| Condition      | Result           |
|----------------|------------------|
| Zero × normal  | ±Zero            |
| Zero × Zero    | +Zero            |
| Inf × normal   | ±Inf             |
| Inf × Inf      | ±Inf             |
| Inf × Zero     | NaN (mandatory)  |
| NaN × anything | NaN              |

---

## File Structure

```
fp_multiplier_dadda/
│
├── rtl/
│   ├── fp_multiplier_32bit.v        # Top-level module
│   ├── sign_block.v                 # XOR sign computation
│   ├── exponent_adder.v             # Biased exponent addition
│   ├── mantissa_multiplier.v        # 24x24 mantissa multiplier (top)
│   ├── booth_encoder.v              # Radix-4 Booth encoder (×13)
│   ├── pp_generator.v               # Narrow 25-bit PP generator (×13)
│   ├── dadda_reduce.v               # Recursive Dadda reduction tree
│   ├── normalization_block.v        # Post-multiply normalization
│   ├── fp_rounding.v                # Round-to-Nearest-Even
│   ├── special_case_handler.v       # Zero/Inf/NaN handling
│   ├── full_adder.v                 # 1-bit full adder primitive
│   ├── half_adder.v                 # 1-bit half adder primitive
│   ├── ripple_carry_adder_8bit.v    # 8-bit RCA (exponent)
│   ├── ripple_carry_adder_n.v       # Parameterized N-bit RCA (CPA)
│   └── ripple_carry_subtractor_8bit.v  # 8-bit subtractor (exponent)
│
├── tb/
│   ├── tb_fp_multiplier.v           # Top-level FP multiplier testbench
│   └── tb_mantissa.v                # Isolated mantissa multiplier testbench
│
├── constraints/
│   └── fp_multiplier.xdc            # Vivado XDC for xc7a100tcsg324-1
│
└── README.md
```

---

## Simulation

### Prerequisites

- Icarus Verilog (`iverilog`) or Xilinx Vivado 2023.2 simulator

### Run with Icarus Verilog

```bash
# Compile all sources + testbench
iverilog -g2005 -o sim_fp \
    tb/tb_fp_multiplier.v \
    rtl/fp_multiplier_32bit.v \
    rtl/mantissa_multiplier.v \
    rtl/dadda_reduce.v \
    rtl/booth_encoder.v \
    rtl/pp_generator.v \
    rtl/ripple_carry_adder_n.v \
    rtl/full_adder.v \
    rtl/half_adder.v \
    rtl/exponent_adder.v \
    rtl/ripple_carry_adder_8bit.v \
    rtl/ripple_carry_subtractor_8bit.v \
    rtl/sign_block.v \
    rtl/normalization_block.v \
    rtl/fp_rounding.v \
    rtl/special_case_handler.v

# Run simulation
vvp sim_fp
```

### Test coverage

The testbench covers the following categories:

| Group | Description                                         |
|-------|-----------------------------------------------------|
| 1     | Design case: 4.125 × 3.707 = 15.2914               |
| 2     | Identity / Unity: x × 1.0 = x                      |
| 3     | Sign combinations: +×+, +×−, −×+, −×−              |
| 4     | Powers of two: exact representations                |
| 5     | Boundary exponents: largest and smallest normal     |
| 6     | Rounding: guard, round, sticky bit scenarios        |
| 7     | Commutativity: A×B == B×A                           |
| 8     | Mantissa edge values: all-ones, all-zeros           |
| 9     | Special cases: Zero, Inf, NaN, Inf×Zero             |
| 10    | Denormal inputs: observed DUT behaviour             |

> _Add simulation waveform screenshot here_

---

## Synthesis Results

Target device: **xc7a100tcsg324-1 (Artix-7)**  
Tool: **Xilinx Vivado 2023.2**  
Design style: Purely combinational, single-cycle

| Metric               | Value        |
|----------------------|--------------|
| Logic Area (LUTs)    | 795          |
| Critical Delay       | 25.210 ns    |
| Flip-Flops           | 0 (combinational) |
| DSP48 blocks         | 0            |
| Target Platform      | Artix-7 FPGA |

> _Add Vivado utilization report screenshot here_

> _Add Vivado timing summary screenshot here_

---

## Test Case Walkthrough

### 4.125 × 3.707 = 15.2914

| Step                | Value                                      |
|---------------------|--------------------------------------------|
| A = 4.125           | `0x40840000` → S=0, E=129, M=0x040000     |
| B = 3.707           | `0x406D3F7D` → S=0, E=128, M=0x6D3F7D    |
| Sign                | 0 ⊕ 0 = **0** (positive)                 |
| Exponent            | 129 + 128 − 127 = **130**                 |
| Ma (24-bit)         | `1.00001000...` = 8650752                 |
| Mb (24-bit)         | `1.11011010...` = 15548285                |
| 48-bit product      | `0x7A54BC740000`                          |
| After rounding      | mantissa = `0x74A978`                     |
| Result              | `0x4174A978` = **15.2914**  ✓             |

---

## Tools Used

| Tool                  | Purpose                              |
|-----------------------|--------------------------------------|
| Xilinx Vivado 2023.2  | Synthesis, implementation, timing    |
| Icarus Verilog 12.0   | RTL simulation and verification      |
| Python 3              | Test vector generation and reference |
| Verilog-2005          | RTL implementation language          |

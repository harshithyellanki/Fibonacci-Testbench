# Fibonacci-Testbench

````markdown
# Fibonacci Hardware Verification – SystemVerilog Testbenches

## Overview
This project demonstrates the development of a powerful testbench in SystemVerilog to detect and correct faulty behavior in a Fibonacci calculator module. The original module (`fib_bad.sv`) contains multiple hidden bugs that are not caught by the provided basic testbench. I built a modular testbench environment, identified and documented all issues, and implemented a synthesizable, fully working design (`fib_good.sv`).

## Tools Used
- Questa (for simulation and functional coverage)
- Vivado (for synthesis)

---

## Algorithm Reference (Pseudocode)
The Fibonacci calculator follows the algorithm below, starting at index 0. For `n < 1`, the output is defined as 0.

```c
int fib(int n) {
    int i = 3;
    int x = 0;
    int y = 1;
    int temp;

    while(i <= n) {
        temp = x + y;
        x = y;
        y = temp;
        i++;
    }

    if (n < 2) return x;
    else return y;
}
````

---

## Design Requirements

* Computation begins when `go` is asserted and `done == 1` or after reset
* `done` is cleared **one cycle after** `go` is asserted
* Inputs `n` and `go` should have **no effect** while the module is active (`done == 0`)
* Outputs `result` and `overflow` should **latch after completion**
* For `n < 1`, output `result = 0`
* `overflow` should assert if result exceeds `OUTPUT_WIDTH`
* Must handle any positive `INPUT_WIDTH` and `OUTPUT_WIDTH` values

---

## Testbench Architecture

The testbench in `fib_tb.sv` includes:

* **Generator** – Stimulus generation for `go` and `n`
* **Driver** – Drives interface signals to the DUT
* **Monitor** – Observes and logs output behavior
* **Scoreboard** – Implements a golden reference model for result comparison
* **Functional Coverage** – Ensures complete specification coverage using SystemVerilog constructs

---

## Coverage Goals

Achieved full coverage under the following criteria using `INPUT_WIDTH = 6` and `OUTPUT_WIDTH = 16`:

* All 64 (`2^6`) values of `n` tested while `go == 1` and `done == 1`
* At least **10 overflows** captured during execution
* **100+ assertions** of `go` while computation is active (`done == 0`)
* **100+ changes** to `n` during computation
* Tested both **immediate** and **delayed** restarts after `done == 1`

Coverage analysis was run using Questa with `+coverage` flag enabled.

---

## Implementation Fix

The corrected design is implemented in `fib_good.sv`. It was rewritten from scratch based on the spec, verified through the testbench, and synthesized in Vivado targeting `xc7a12tcpg238-3`. No critical warnings were observed in synthesis.

---

## Directory Structure

```
├── src
│   ├── fib_bad.sv        # Faulty module used for bug discovery
│   ├── fib_good.sv       # Corrected and synthesizable version
│   ├── fib.sv            # (Optional) shared interface
├── tests
│   ├── fib_tb_basic.sv   # Instructor's original weak testbench
│   └── fib_tb.sv         # My modular testbench with coverage
├── README.md             # Project overview and documentation
├── report.pdf            # Detailed bug reports, coverage, synthesis screenshots
└── sources.txt           # Source file list for simulation/synthesis
```

---

## Notes

The `report.pdf` includes:

* Waveforms and traces of detected bugs in `fib_bad.sv`
* Description of all tests written and how they uncovered design flaws
* Coverage results (including overflow counts and assertion stats)
* Screenshot of Vivado synthesis results for `fib_good.sv`

This project highlights advanced verification methodologies, coverage-driven testing, and RTL design correction in SystemVerilog.

```

Let me know if you want a matching `report.pdf` LaTeX template or a GitHub "About" section summary too.
```

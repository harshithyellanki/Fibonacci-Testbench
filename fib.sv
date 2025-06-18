// Top-level module for synthesis and simulation, change the instantiated
// module to test different modules.

module fib #(
    parameter string ARCH = "fib_bad",  // "fib_bad" or "fib_good"
    parameter int INPUT_WIDTH = 6,
    parameter int OUTPUT_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    go,
    input  logic [ INPUT_WIDTH-1:0] n,
    output logic [OUTPUT_WIDTH-1:0] result,
    output logic                    overflow,
    output logic                    done
);

  // verilog_format: off
  if (ARCH == "fib_bad") begin : g_fib_bad
    fib_bad #( .INPUT_WIDTH(INPUT_WIDTH), .OUTPUT_WIDTH(OUTPUT_WIDTH) ) top ( .* );
  end else if (ARCH == "fib_good") begin : g_fib_good
    fib_good #( .INPUT_WIDTH(INPUT_WIDTH), .OUTPUT_WIDTH(OUTPUT_WIDTH) ) top ( .* );
  end else begin : g_error
    $error("Invalid architecture specified.");
  end
  // verilog_format: on

endmodule

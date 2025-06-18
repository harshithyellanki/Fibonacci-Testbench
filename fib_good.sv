module fib_good #(
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

  typedef enum {
    START,
    COND,
    COMPUTE,
    OVERFLOW,
    DONE,
    RESTART
  } state_t;
  state_t state_r;

  logic [$bits(result)-1:0] i_r;
  logic [$bits(result)-1:0] x_r;
  logic [$bits(result)-1:0] y_r;
  logic [$bits(result):0] full_add_r;
  logic [INPUT_WIDTH-1:0] n_r;

  logic [$bits(result)-1:0] result_r;
  logic done_r, overflow_r;

  assign done = done_r;
  assign result = result_r;
  assign overflow = overflow_r;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state_r <= START;
      result_r <= '0;
      done_r <= 1'b0;
      i_r <= '0;
      x_r <= '0;
      y_r <= '0;
      overflow_r <= 1'b0;
      full_add_r <= '0;
    end else begin

      case (state_r)
        START: begin
          i_r <= 3;
          x_r <= '0;
          y_r <= 1;
          if (go == 1'b1)begin
           state_r <= COND;
           n_r <= n;
	  done_r <= 1'b0;
        end
      end

        COND: begin
          

          if (i_r <= n_r) state_r <= COMPUTE;
          else state_r <= DONE;
        end

        COMPUTE: begin
          x_r <= y_r;
          full_add_r <= x_r + y_r;
          i_r <= i_r + 1'b1;
          state_r <= OVERFLOW;
        end

        OVERFLOW: begin
          if (full_add_r[OUTPUT_WIDTH]) overflow_r <= 1'b1;
          y_r <= full_add_r;
          state_r <= COND;
        end

        DONE: begin
          if (n_r < 2) result_r <= x_r;
          else result_r <= y_r;

          done_r  <= 1'b1;
          state_r <= RESTART;
        end

        RESTART: begin
          if (go == 1'b1) begin
         state_r <= COND;
                n_r <= n;
                i_r <= 3;
                x_r <= '0;
                y_r <= 1;
	            overflow_r <= 1'b0;
                done_r <= 1'b0;
        end
      end
      endcase

     
    end
  end
endmodule
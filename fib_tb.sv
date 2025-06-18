// Module: fib_tb
module fib_tb #(
    localparam int NUM_TESTS = 1000,
    parameter string ARCH = "fib_bad",  // "fib_bad" or "fib_good"
    parameter int INPUT_WIDTH = 6,
    parameter int OUTPUT_WIDTH = 32,
    parameter bit TOGGLE_INPUTS_WHILE_ACTIVE = 1'b1,
    parameter bit LOG_START_MONITOR = 1'b1,
    parameter bit LOG_DONE_MONITOR = 1'b1,
    parameter int MIN_CYCLES_BETWEEN_TESTS = 1,
    parameter int MAX_CYCLES_BETWEEN_TESTS = 10
);

    logic clk = 1'b0, rst, go, done, overflow;
    logic [INPUT_WIDTH-1:0] n;
    logic [OUTPUT_WIDTH-1:0] result;
    longint correct_result;
    logic correct_overflow;
    int passed;
    int failed;
    int overflow_passed;
    int overflow_failed;

    mailbox driver_mailbox = new();
    mailbox scoreboard_result_mailbox = new();
    mailbox scoreboard_data_mailbox = new();
    mailbox scoreboard_overflow_mailbox = new();

    // Instantiate DUT
    fib #(
        .ARCH        (ARCH),
        .INPUT_WIDTH (INPUT_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) DUT (
        .*
    );

    class fib_item;
        rand bit [INPUT_WIDTH-1:0] n;
    endclass

    function int model(int n, int width);
        automatic int temp = '0;
        automatic int i = 2;
        automatic int x = 0;
        automatic int y = 1;

        if(n===0) return 0;
        if(n===1) return 0;
        if(n===2) return 1;

        while (i <= n) begin 
            temp = x + y;
            x = y;
            y = temp;


          //  temp = temp[OUTPUT_WIDTH-1:0];
            i = i + 1'b1;
        end 

        if(n > 2) return y;
    endfunction

//     function logic overflow_model(longint result);
//     logic [OUTPUT_WIDTH-1:0] result_truncated;
//     result_truncated = result;


//     // if(result_truncated == result) return 0;

//     // if(result_truncated != result) return 1;
//     // If the truncated version is the same as the full version, there
//     // was no overflow.
//    return result_truncated != result;
//   endfunction


    function logic overflow_model(longint unsigned result);
    logic [OUTPUT_WIDTH-1:0] result_truncated;
    
    // Extract only OUTPUT_WIDTH bits from result
    result_truncated = result[OUTPUT_WIDTH-1:0];

    // Overflow occurs if result exceeds the max value that OUTPUT_WIDTH can hold
    return (result >= (1 << OUTPUT_WIDTH)); 
    endfunction

//     function logic overflow_model(longint unsigned result);
//     logic [OUTPUT_WIDTH-1:0] result_truncated;

//     // Extract only OUTPUT_WIDTH bits from result
//     result_truncated = result[OUTPUT_WIDTH-1:0];

//     // Debugging prints
//     $display("Checking Overflow: result = %0d, truncated = %0d", result, result_truncated);

//     // Overflow occurs if result_truncated is not equal to the original result
//     return (result_truncated != result);
// endfunction


    // Generate clock
    initial begin : generate_clock
        forever #5 clk <= ~clk;
    end 

    initial begin : initialization 
        $timeformat(-9, 0, " ns");
        rst <= 1'b1;
        go <= 1'b0;
        n <= '0;
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst <= 1'b0;
    end

    initial begin : generator 
        fib_item test;

        for (int i = 0; i < NUM_TESTS; i++) begin
            test = new();
            assert(test.randomize()) else $fatal(1, "Randomization failed");
            driver_mailbox.put(test);
        end
    end 

    initial begin : driver 
        fib_item test;
        @(posedge clk iff !rst);

        forever begin
            driver_mailbox.get(test);
            n <= test.n;
            go <= 1'b1;
            @(posedge clk);
           // $display("[%0t] Start monitor detected test with data=%0b", go); 
            go <= 1'b0;
            @(posedge clk);

            if (TOGGLE_INPUTS_WHILE_ACTIVE) begin
                while (!done) begin
                    n <= $urandom;
                    go <= $urandom;
                    @(posedge clk);
                end
            end else begin
                @(posedge clk iff (done == 1'b1));
            end

            repeat ($urandom_range(MIN_CYCLES_BETWEEN_TESTS - 1, MAX_CYCLES_BETWEEN_TESTS - 1)) @(posedge clk);
        end
    end 

    initial begin : start_monitor
        logic active_test = 1'b0;  // Lock to ensure only one test is recorded at a time
    
        forever begin
            @(posedge clk);
            
            if (!rst && go && !active_test) begin
                scoreboard_data_mailbox.put(n);
                active_test = 1'b1; // Lock the test
                if (LOG_START_MONITOR) 
                    $display("[%0t] Start monitor detected test with data=%0d", $realtime, n);
            end
    
            if (done) begin
                active_test = 1'b0; // Unlock when done
            end
        end
    end

    initial begin : done_monitor
        logic test_active = 1'b0;  // Lock to track active tests
    
        forever begin
            @(posedge clk);
            
            if (!rst && go && !test_active) begin
                test_active = 1'b1;  // Mark that a test is in progress
            end
    
            if (test_active && done) begin
                scoreboard_result_mailbox.put(result);
                scoreboard_overflow_mailbox.put(overflow);
                if (LOG_DONE_MONITOR) 
                    $display("[%0t] Done monitor detected completion with result=%0d", $realtime, result);
                test_active = 1'b0;  // Unlock when done
            end
        end
    end

    initial begin : scoreboard 
        logic [INPUT_WIDTH-1:0] n;
        logic  [OUTPUT_WIDTH-1:0] actual;
        longint expected;
        logic correct_overflow, actual_overflow;

        overflow_passed = 0;
        overflow_failed = 0;
        passed = 0;
        failed = 0;
    
        for (int i = 0; i < NUM_TESTS; i++) begin
            scoreboard_data_mailbox.get(n);
            scoreboard_result_mailbox.get(actual);
            scoreboard_overflow_mailbox.get(actual_overflow);
    
            expected = model(n, INPUT_WIDTH);  // Get the expected result
         //correct_overflow = (expected > 64'd4294967296) ? 1'b1 : 1'b0;
          //  correct_overflow = (expected >= (1 << OUTPUT_WIDTH)) ? 1'b1 : 1'b0; 
           correct_overflow = overflow_model(expected);  // Check expected overflow
            $display("\n");
           // Validate result
            if (!correct_overflow) begin
                if (actual == expected) begin
                    $display("Test passed (time %0t) for input = %0d", $time, n);
                    passed++;
                end else begin
                    $display("Test failed (time %0t): result = %0d instead of %0d for input = %0d.", 
                             $time, actual, expected, n);
                    failed++;
                end
            end
    

       //     $display("seperation of tests");




            // Validate overflow for this specific test case
            if (actual_overflow == correct_overflow) begin
                // Overflow passed
                $display("Overflow test passed (time %0t): overflow = %0b matching with expected %0b.", $time, overflow,
                 correct_overflow);
                overflow_passed++;
            end else begin
                $display("Overflow test failed (time %0t): overflow = %0b instead of %0b for input = %0d.", 
                         $time, actual_overflow, correct_overflow, n);
                overflow_failed++;
            end

            $display("\n");
        end



     

        // if ((!correct_overflow && (actual == expected)) || 
        // (correct_overflow && (overflow == correct_overflow))) 
        // // $display("\n");
        // begin
        // $display("Test %0d/%0d PASSED @ %0t: n=%0d | Result: %0d (exp: %0d) | Overflow: %0b (exp: %0b)",
        //         i+1, NUM_TESTS, $time, n, actual, expected, overflow, correct_overflow);
        // passed++;
        // end
        // else begin
        // $error("Test %0d/%0d FAILED @ %0t: n=%0d", i+1, NUM_TESTS, $time, n);
        // $error("  Result: got %0d, expected %0d (overflow expected: %0b)", 
        //     actual, expected, correct_overflow);
        // $error("  Overflow: got %0b, expected %0b", overflow, correct_overflow);
        // failed++;
        // end
        // $display("\n");
        // end

    /*    if (overflow === expected_overflow) begin
            if (!expected_overflow && (actual != expected)) begin
                $display("Test failed (time %0t): result = %0d instead of %0d for input = %0d.", 
                         $time, actual, expected, n);
                failed++;
            end else begin
                $display("Test passed (time %0t) for input = %0d", $time, n);
                passed++;
            end
        end else begin
            $display("Overflow test failed (time %0t): overflow = %0b instead of %0b for input = %0d.", 
                     $time, overflow, expected_overflow, n);
            failed++;
        end
    end
    */
    $display(" Overflow Tests completed: %0d passed, %0d failed", overflow_passed, overflow_failed);
        $display("Tests completed: %0d passed, %0d failed", passed, failed);
        disable generate_clock;
    end


    assert property (@(posedge clk) disable iff (rst) (go && (done || $past(rst))) |=> !done);
    //The module should start computing when go is asserted and the module is inactive. It is inactive anytime done == 1, or after reset.
    // assert property ((@posedge clk) disable iff (rst) go && done |=> ); // only starts when the module is inactive
    assert property (@(posedge clk) disable iff (rst) go && done |=> !done); //When the circuit is restarted (i.e. go == 1 and done == 1), done should be cleared on the cycle following the assertion of go. Clearing done within the same cycle, or more than one cycle later is incorrect behavior.
    assert property (@(posedge clk) disable iff (rst) $fell(done) |=> $past(go,1)); //similar condition to the above assertion
    assert property (@(posedge clk) disable iff (rst) done == 1'b1 |=> $stable(result))
    else $error("Result should remain stable after completion!");

    assert property (@(posedge clk) disable iff (rst) done == 1'b1 |=> $stable(overflow))
    else $error("Overflow should remain stable after completion!");

    assert property (@(posedge clk) disable iff (rst) (!go && done == 1'b1) |=> done == 1'b1);

    assert property (@(posedge clk) disable iff (rst) (go && done && overflow) |=> !overflow);




    logic go_done_immediate, go_done_delayed;
logic prev_done;
int go_during_active = 0;
int n_changes_active = 0;

// Track previous state of `done`
always @(posedge clk) begin
    prev_done <= done;
end

logic [INPUT_WIDTH-1:0] prev_n;
always_ff @(posedge clk) begin
    if (!rst && go && !done)
        go_during_active++;
    if (!rst && !done && (n != prev_n))
        n_changes_active++;
    prev_n <= n;
end

// Overflow on done
cover property (@(posedge clk) disable iff (rst)
    (done && overflow));

// Go asserted during active
cover property (@(posedge clk) disable iff (rst)
    (go && !done));

// n changed while active
cover property (@(posedge clk) disable iff (rst)
    (!done && (n != $past(n))));

// ? Fixed: go asserted in same cycle as done rises
cover property (@(posedge clk) disable iff (rst)
    ($rose(done) && go));

// go asserted after delay post-done
cover property (@(posedge clk) disable iff (rst)
    $rose(done) ##[2:$] go);

// Define the new variables for coverpoints
always @(posedge clk) begin
    go_done_immediate <= prev_done && go;
    go_done_delayed   <= prev_done && !go;
end

covergroup coverage;
    coverpoint overflow iff (done) {
        option.at_least = 10;
    }

    coverpoint n iff (go && !done) {  
        bins all_values[] = {[0:2**INPUT_WIDTH-1]};
        option.at_least = 2**INPUT_WIDTH;
    }

    coverpoint go iff (!done) {
        option.at_least = 100;
    }

    coverpoint go_done_immediate {  // Use variable instead of expression
        option.at_least = 1;
    }

    coverpoint go_done_delayed {  // Use variable instead of expression
        option.at_least = 1;
    }
endgroup

coverage cov_inst = new();
initial begin
  cov_inst.sample();
end

endmodule

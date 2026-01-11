`timescale 1ns/1ps

module test(a, b, c, d);
    input a, b; // this is a comment
    /* this is
       a block comment */
    assign c = a; assign d = ~b;
    output c, d;
endmodule

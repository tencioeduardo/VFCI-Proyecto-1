`ifndef DUT_WRAPPER_SV
`define DUT_WRAPPER_SV

module dut_wrapper #(
    parameter BITS      = 1,
    parameter DRVRS     = 4,
    parameter PCKG_SZ   = 16,
    parameter BROADCAST = {8{1'b1}}
)(
    input clk,
    bus_if.dut_mp intf [DRVRS]  
);

    wire               pndng_arr  [BITS-1:0][DRVRS-1:0];
    wire               push_arr   [BITS-1:0][DRVRS-1:0];
    wire               pop_arr    [BITS-1:0][DRVRS-1:0];
    wire [PCKG_SZ-1:0] D_pop_arr  [BITS-1:0][DRVRS-1:0];
    wire [PCKG_SZ-1:0] D_push_arr [BITS-1:0][DRVRS-1:0];

    genvar i;
    generate
        for(i = 0; i < DRVRS; i++) begin : map_intf
            assign pndng_arr[0][i]  = intf[i].pndng; 
            
            assign intf[i].push     = push_arr[0][i];
            assign intf[i].pop      = pop_arr[0][i];
            
            assign D_pop_arr[0][i]  = intf[i].D_pop;
            assign intf[i].D_push   = D_push_arr[0][i];
        end
    endgenerate

    bs_gnrtr_n_rbtr #(
        .bits(BITS),
        .drvrs(DRVRS),
        .pckg_sz(PCKG_SZ),
        .broadcast(BROADCAST)
    ) dut_real (
        .clk(clk),
        .reset(intf[0].reset),
        .pndng(pndng_arr),
        .push(push_arr),
        .pop(pop_arr),
        .D_pop(D_pop_arr),
        .D_push(D_push_arr)
    );

endmodule

`endif // DUT_WRAPPER_SV

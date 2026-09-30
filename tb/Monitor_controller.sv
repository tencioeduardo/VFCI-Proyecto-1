`ifndef MONITOR_CONTROLLER_SV
`define MONITOR_CONTROLLER_SV

// -----------------------------------------------------------------
// Monitor_controller: instancia los 4 Monitor_son (uno por
// dispositivo), reenvía todo lo que observan hacia mon2chk_mbx, y
// agrega el centinela EV_RESET (una sola vez por evento de reset,
// sin spam) para que el Checker sepa cuándo limpiar sus colas.
//
// Comparte los handles v_bif[4] con el Driver_controller: no
// instancia interfaces propias (decisión 3.E).
// -----------------------------------------------------------------
class Monitor_controller #(parameter pckg_sz = `PCKG_SZ);
    virtual bus_if #(.pckg_sz(pckg_sz)) v_bif [4];
    trans_bus_mbx                       mon_son_mbx [4];
    trans_bus_mbx                       mon2chk_mbx;
    Monitor_son #(pckg_sz)              children [4];
    bit                                 reset_sent;

    function new(trans_bus_mbx mon2chk_mbx,
                 virtual bus_if #(.pckg_sz(pckg_sz)) v_bif [4]);
        this.mon2chk_mbx = mon2chk_mbx;
        this.reset_sent  = 1'b0;
        foreach (v_bif[i]) begin
            this.v_bif[i]  = v_bif[i];
            mon_son_mbx[i] = new();
            children[i]    = new(i, v_bif[i], mon_son_mbx[i]);
        end
    endfunction

    task run();
        fork
            begin
                foreach (children[i]) children[i].run();
            end
            recolectar_hijos();
            watchdog_reset();
        join_none
    endtask

    // Un proceso "forever" por hijo, cada uno capturando su propio
    // índice con `automatic int idx = i` (directriz #4).
    task recolectar_hijos();
        foreach (mon_son_mbx[i]) begin
            automatic int idx = i;
            fork
                begin
                    trans_bus t;
                    forever begin
                        mon_son_mbx[idx].get(t);
                        mon2chk_mbx.put(t);
                    end
                end
            join_none
        end
    endtask

    // Observa el reset a través de la interface 0 (reset global
    // compartido por los 4 dispositivos, ver SUPUESTOS A VALIDAR) y
    // emite UN solo centinela EV_RESET por flanco de subida, sin
    // repetirlo mientras el reset se mantenga asertado.
    task watchdog_reset();
        trans_bus t;
        forever begin
            @(posedge v_bif[0].clk);
            if (v_bif[0].reset && !reset_sent) begin
                reset_sent  = 1'b1;
                t           = new();
                t.mon_kind  = EV_RESET;
                t.device_id = 0;
                mon2chk_mbx.put(t);
            end
            else if (!v_bif[0].reset) begin
                reset_sent = 1'b0;
            end
        end
    endtask

endclass

`endif // MONITOR_CONTROLLER_SV

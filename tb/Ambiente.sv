//============================================
// Clase Ambiente
//============================================

`ifndef AMBIENTE_SV
`define AMBIENTE_SV

class Ambiente #(parameter pckg_sz = 16) ;
    virtual bus_if #(.pckg_sz(pckg_sz)) v_bif [4];
    bus_config                          cfg;

    //--------------------------------------------------------
    // ── Componentes (transactores)
    //--------------------------------------------------------
    Driver_controller  drv_controller_inst;
    Monitor_controller mon_controller_inst;
    Checker            check_inst;
    Agente             agent_inst;
    Generador          gen_inst;
    Scoreboard         sb_inst;


    //--------------------------------------------------------
    // ── Canales (mailboxes)
    //--------------------------------------------------------
    trans_bus_mbx   agent_drvr_mbx;       // Driver_controller - Agente
    trans_bus_mbx   agent_scorb_mbx;      // Scoreboard - Agente
    trans_bus_mbx   mon2chk_mbx;          // Monitor_controller - Checker
    trans_bus_mbx   sb2chk_mbx;           // Checker - Scoreboard
    instruc_gen_mbx gen_agent_mbx;        // Agente - Generador
    order_test_mbx  tst_gen_mbx;          // Generador - Test


    function new(virtual bus_if #(.pckg_sz(pckg_sz)) v_bif[4]);
        this.v_bif = v_bif;
        this.cfg   = bus_config::get();
    endfunction


    function void build();
        agent_drvr_mbx  = new();
        agent_scorb_mbx = new();
        mon2chk_mbx     = new();
        sb2chk_mbx      = new();
        gen_agent_mbx   = new();
        tst_gen_mbx     = new();

        drv_controller_inst = new(agent_drvr_mbx, v_bif);
        mon_controller_inst = new(mon2chk_mbx, v_bif);
        check_inst          = new(mon2chk_mbx, sb2chk_mbx);
        agent_inst          = new(gen_agent_mbx, agent_scorb_mbx, agent_drvr_mbx);
        gen_inst            = new(gen_agent_mbx, tst_gen_mbx);
        sb_inst             = new(agent_scorb_mbx, sb2chk_mbx);
    endfunction


    task reset();
        drv_controller_inst.reset();
    endtask


    task run();
        fork
            drv_controller_inst.run();
            mon_controller_inst.run();
            check_inst.run();
            agent_inst.run();
            sb_inst.run();
            gen_inst.run();
        join_none
    endtask


    function void wrap_up();
        check_inst.wrap_up();
    endfunction

endclass : Ambiente

`endif // AMBIENTE_SV

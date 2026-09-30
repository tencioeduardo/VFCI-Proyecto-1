`include "bus_includes.svh"   // Agrupa todos los `include

program automatic Test (
    bus_if vif [4]
);

    Ambiente   env;
    bus_config cfg;

    initial begin
        //--------------------------------------------------------------
        // Configuración
        //--------------------------------------------------------------
        cfg = bus_config::get();


        //--------------------------------------------------------------
        // Watchdog: vita que una combinación rara de plusargs
        // cuelgue la simulación indefinidamente
        //--------------------------------------------------------------
        fork
            begin
                repeat (cfg.timeout) @(posedge vif[0].clk);
                $display("WATCHDOG: tiempo límite excedido");
                $finish;
            end
        join_none


        //--------------------------------------------------------------
        // Construcción y arranque del ambiente
        //--------------------------------------------------------------
        env = new(vif);
        env.build();
        env.reset();
        env.run();


        //--------------------------------------------------------------
        // Escenarios de pruebas a realizar
        //--------------------------------------------------------------
        correr_arbitraje_simultaneo();
        correr_broadcast();
        correr_direccion_invalida();
        correr_terminal_acaparador();
        correr_autoenvio();
        correr_aleatorio();


        //--------------------------------------------------------------
        // Drenar y reportar
        //--------------------------------------------------------------
        repeat (cfg.drain_cycles) @(posedge vif[0].clk);
        env.wrap_up();


        $display("[%0t] Test finalizado.", $time);
        $finish;
    end


    //-------------------------------------------------------------------
    task correr_arbitraje_simultaneo();
        order_test orden = new();

        orden.tipo = scen_arbitraje_simultaneo;

        env.tst_gen_mbx.put(orden);
        repeat (20) @(posedge vif[0].clk);
    endtask


    task correr_broadcast();
        order_test orden = new();

        orden.tipo            = scen_broadcast;
        orden.terminal_origen = cfg.broadcast_origen;

        env.tst_gen_mbx.put(orden);
        repeat (20) @(posedge vif[0].clk);
    endtask


    task correr_direccion_invalida();
        order_test orden = new();

        orden.tipo = scen_invalido;

        env.tst_gen_mbx.put(orden);
        repeat (20) @(posedge vif[0].clk);
    endtask


    task correr_terminal_acaparador();
        order_test orden = new();

        orden.tipo            = scenEsq_disponibilidad;
        orden.terminal_origen = cfg.acaparador_origen;
        orden.cantidad        = cfg.acaparador_cantidad;

        env.tst_gen_mbx.put(orden);
        repeat (30) @(posedge vif[0].clk);
    endtask


    task correr_autoenvio();
        order_test orden = new();

        orden.tipo            = scen_autodirec;
        orden.terminal_origen = cfg.autoenvio_origen;
        env.tst_gen_mbx.put(orden);

        repeat (10) @(posedge vif[0].clk);
    endtask


    task correr_aleatorio();
        order_test orden = new();

        orden.tipo             = scen_aleatorio_sec;
        orden.cantidad         = cfg.n_soak;
        orden.delay_secuencia  = cfg.soak_delay;

        env.tst_gen_mbx.put(orden);
        repeat (cfg.n_txn_soak * 5) @(posedge vif[0].clk);
    endtask

endprogram : Test

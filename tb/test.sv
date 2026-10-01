//============================================
// Programa del Test
//============================================

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
        // Watchdog: Tiempo limite para la simulación
        //--------------------------------------------------------------
        fork
            begin
                repeat (cfg.timeout) @(posedge vif[0].clk);
              	$display("T=%0t [TEST] Watchdog: Time limit exceeded.", $time);
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
      	env.wait_empty();  // Espera dinámica a que el sistema se limpie
        env.wrap_up();


      	$display("T=%0t [TEST] Test completed.", $time);
        $finish;
    end

    //--------------------------------------------------------------
    // Tareas para los escenarios de pruebas
    //--------------------------------------------------------------
    task correr_arbitraje_simultaneo();
        order_test orden = new();

        orden.tipo = scen_arbitraje_simultaneo;

        env.tst_gen_mbx.put(orden);
        repeat (10) @(posedge vif[0].clk);
    endtask


    task correr_broadcast();
        order_test orden = new();

        orden.tipo            = scen_broadcast;
        orden.terminal_origen = cfg.broadcast_origen;

        env.tst_gen_mbx.put(orden);
        repeat (10) @(posedge vif[0].clk);
    endtask


    task correr_direccion_invalida();
        order_test orden = new();

        orden.tipo = scen_invalido;

        env.tst_gen_mbx.put(orden);
        repeat (10) @(posedge vif[0].clk);
    endtask


    task correr_terminal_acaparador();
        order_test orden = new();

        orden.tipo            = scen_dispSos;
        orden.terminal_origen = cfg.acaparador_origen;
        orden.cantidad        = cfg.acaparador_cantidad;

        env.tst_gen_mbx.put(orden);
        repeat (10) @(posedge vif[0].clk);
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
    	repeat (10) @(posedge vif[0].clk);
    endtask

endprogram : Test

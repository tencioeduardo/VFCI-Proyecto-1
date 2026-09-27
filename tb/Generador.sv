//============================================
// Clase Generador (capa de escenario)
//============================================
// Conexion al Test por medio de: tst_gen_mbx
// Conexion al Agente por medio de: gen_agent_mbx

`ifndef GENERADOR_SV
`define GENERADOR_SV

class Generador;

    instruc_gen_mbx gen_agent_mbx;
    order_test_mbx  tst_gen_mbx;
    bus_config      cfg;            // puntero al archivo de config

    function new(
        instruc_gen_mbx gen_agent_mbx,
        order_test_mbx  tst_gen_mbx
    );
        this.gen_agent_mbx = gen_agent_mbx;
        this.tst_gen_mbx   = tst_gen_mbx;

        cfg = bus_config::get();
    endfunction


    // ── Proceso padre: Inicia el agente (clasifica las instrucciones)
    task run();
        $display("T=%0t [GENERADOR] Starting...", $time);

        order_test order;   // <-- Objeto de orden proveniente del Test

        forever begin
            $display("T=%0t [GENERADOR] Waiting for an order...", $time);

            tst_gen_mbx.get(order);

            case (order.tipo)
                scen_aleatorio_sec:        escenario_aleatorio_sec(order);
                scen_aleatorio:            escenario_aleatorio();
                scen_arbitraje_simultaneo: escenario_arbitraje_simultaneo();
                scen_broadcast:            escenario_broadcast();
                scen_invalido:             escenario_invalido();
                scen_dispSos:              escenario_dispSostenida(order);
                scen_autodirec:            escenario_autoenvio();

                default: escenario_aleatorio();
            endcase
        end
    endtask


    // ── Proceso 1: Delega al mecanismo de aleatorizacion (secuencial)
    task escenario_aleatorio_sec(order_test order);
        $display("T=%0t [GENERADOR] Generating %d random scenarios...", $time,
                order.cantidad_secuencia);
        instruc_gen instruction = new();

        instruction.tipo     = trans_secuencial;
        instruction.cantidad = order.cantidad_secuencia;

        gen_agent_mbx.put(instruction);
    endtask


    // ── Proceso 2: Delega al mecanismo de aleatorizacion
    task escenario_aleatorio();

        $display("T=%0t [GENERADOR] Generating a random scenario...", $time);
        instruc_gen instruction = new();

        instruction.tipo = trans_aleatoria;

        gen_agent_mbx.put(instruction);
    endtask


    // ── Proceso 3: Genera un trafico para arbitraje simultaneo
    task escenario_arbitraje_simultaneo();

        $display("T=%0t [GENERADOR] Generating simultaneous traffic...", $time);

        // ── Genera paquetes para los 4 dispositivos
        //    (el payload se delega a la aleatorizacion).
        for (int i = 0; i < 4; i++) begin
            instruc_gen instruction = new();

            instruction.tipo = trans_dirigida;

            instruction.id_origen      = i;
            instruction.set_id_origen  = 1'b1;
            instruction.id_destino     = (i + 1) % 4;   // <-- ID ciclico
            instruction.set_id_destino = 1'b1;
            instruction.delay          = 0;
            instruction.set_delay      = 1'b1;
            instruction.set_payload    = 1'b0;

            gen_agent_mbx.put(instruction);
        end
    endtask


    // ── Proceso 4: Realiza el escenario de broadcast
    task escenario_broadcast();

        $display("T=%0t [GENERADOR] Generating a broadcast scenario on all devices...", $time);

        // ── Genera paquetes de broadcast para los 4 dispositivos
        //    (el payload se delega a la aleatorizacion).
        for (int i = 0; i < 4; i++) begin
            instruc_gen instruction = new();

            instruction.tipo = trans_dirigida;

            instruction.id_origen      = i;
            instruction.set_id_origen  = 1'b1;
            instruction.id_destino     = 8'hFF; // <-- ID de broadcast
            instruction.set_id_destino = 1'b1;
            instruction.delay          = 5;     // <-- Da tiempo a cada dispositivo para broadcast
            instruction.set_delay      = 1'b1;
            instruction.set_payload    = 1'b0;

            gen_agent_mbx.put(instruction);
        end
    endtask


    // ── Proceso 5: Realiza un escenario invalido
    task escenario_invalido();

        $display("T=%0t [GENERADOR] Generating an invalid scenario on all devices...", $time);

        // ── Genera paquetes invalidos en los 4 dispositivos.
        for (int i = 0; i < 4; i++) begin
            instruc_gen instruction = new();

            instruction.tipo = trans_dirigida;

            instruction.id_origen      = i;
            instruction.set_id_origen  = 1'b1;
            instruction.id_destino     = cfg.id_invalido;
            instruction.set_id_destino = 1'b1;
            instruction.delay          = 0;
            instruction.set_delay      = 1'b1;
            instruction.set_payload    = 1'b0;

            gen_agent_mbx.put(instruction);
        end
    endtask

    // ── Proceso 6: Realiza un escenario de disponibildad sostenida
    task escenario_dispSostenida(order_test order);
        $display("T=%0t [GENERADOR] Terminal %0d requesting bus %0d times in a row...", $time,
                order.terminal_origen, order.cantidad_secuencia);

        repeat(order.cantidad_secuencia) begin
            instruc_gen instruction = new();

            instruction.tipo = trans_dirigida;

            instruction.id_origen      = order.terminal_origen;
            instruction.set_id_origen  = 1'b1;
            instruction.set_id_destino = 1'b0;
            instruction.delay          = 0;
            instruction.set_delay      = 1'b1;
            instruction.set_payload    = 1'b0;

            gen_agent_mbx.put(instruction);
        end
    endtask

    // ── Proceso 7: Realiza un escenario de autoenvio
    task escenario_autoenvio(order_test order);
        $display("T=%0t [GENERADOR] Terminal %0d sending to itself...", $time,
                order.terminal_origen);
        instruc_gen instruction = new();

        instruction.tipo = trans_dirigida;

        instruction.id_origen      = order.terminal_origen;
        instruction.set_id_origen  = 1'b1;
        instruction.id_destino     = order.terminal_origen;
        instruction.set_id_destino = 1'b1;
        instruction.delay          = 0;
        instruction.set_delay      = 1'b1;
        instruction.set_payload    = 1'b0;

        gen_agent_mbx.put(instruction);
    endtask

endclass : Generador

`endif // GENERADOR_SV

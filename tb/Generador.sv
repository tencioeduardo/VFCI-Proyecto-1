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

    function new(
        instruc_gen_mbx gen_agent_mbx,
        order_test_mbx  tst_gen_mbx
    );
        this.gen_agent_mbx = gen_agent_mbx;
        this.tst_gen_mbx   = tst_gen_mbx;
    endfunction


    // ── Proceso padre: Inicia el agente (clasifica las instrucciones)
    task run();
        $display("T=%0t [GENERADOR] Starting...", $time);

        order_test order;   // <-- Objeto de orden proveniente del Test

        forever begin
            $display("T=%0t [GENERADOR] Waiting for an order...", $time);

            tst_gen_mbx.get(order);

            case (order)
                scen_aleatorio_sec:        escenario_aleatorio_sec(order.cantidad);
                scen_aleatorio:            escenario_aleatorio();
                scen_arbitraje_simultaneo: escenario_arbitraje_simultaneo();
                scen_broadcast:            escenario_broadcast();
                scen_invalido:             escenario_invalido();
                scen_pckg_sz:              escenario_random_pckg_sz();


                default: escenario_aleatorio(5);
            endcase
        end
    endtask


    // ── Proceso 1: Delega al mecanismo de aleatorizacion (secuencia)
    task escenario_aleatorio_sec(int unsigned n);

        $display("T=%0t [GENERADOR] Generating %d random scenarios...", $time, n);
        instruc_gen instruction = new();

        instruction.tipo     = trans_secuencial;
        instruction.cantidad = n;

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
        for (int i = 0; i < 4; i++) begin
            instruc_gen instruction = new();

            instruction.tipo = trans_dirigida;

            instruction.id_origen  = i;
            instruction.id_destino = (i + 1) % 4;   // <-- ID ciclico
            instruction.delay      = 0;

            // ── Aleatoriza el payload
            if (!std::randomize(instruction.payload)) begin
                $error("T=%0t [GENERADOR] Failed to randomize instruction payload.", $time);
            end

            gen_agent_mbx.put(instruction);
        end
    endtask


    // ── Proceso 4: Realiza el escenario de broadcast
    task escenario_broadcast();

        $display("T=%0t [GENERADOR] Generating a broadcast scenario on all devices...", $time);

        // ── Genera paquetes de broadcast para los 4 dispositivos
        for (int i = 0; i < 4; i++) begin
            instruc_gen instruction = new();

            instruction.tipo = trans_dirigida;

            instruction.id_origen  = i;
            instruction.id_destino = 8'hFF; // <-- ID de broadcast
            instruction.delay      = 5;     // <-- Da tiempo a cada dispositivo para broadcast

            // ── Aleatoriza el payload
            if (!std::randomize(instruction.payload)) begin
                $error("T=%0t [GENERADOR] Failed to randomize instruction payload.", $time);
            end

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

            instruction.id_origen  = i;
            instruction.delay      = 0;

            // ── Aleatoriza controladamente el ID destino
            if (!std::randomize(instruction.id_destino) with {
                instruction.id_destino inside {[5 : 255]};
            }) begin
                $error("T=%0t [GENERADOR] Failed to randomize invalid destination.", $time);
            end

            // ── Aleatoriza el payload
            if (!std::randomize(instruction.payload)) begin
                $error("T=%0t [GENERADOR] Failed to randomize instruction payload.", $time);
            end

            gen_agent_mbx.put(instruction);
        end
    endtask

    // ── Proceso 5: Realiza una aleatorizacion en el pckg_sz para cada dispositivo
    task escenario_random_pckg_sz();


    endtask



endclass : Generador

`endif // GENERADOR_SV

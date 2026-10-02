//===================================================================
// Clase Driver_hijo para cada dispositivo del DUT (capa de comando)
//===================================================================
// Conexion al Driver_padre por medio de: drvr_son_mbx
// Tipo de paquetes en el mailbox: trans_bus

`ifndef DRIVER_SON_SV
`define DRIVER_SON_SV

class Driver_son #(parameter pckg_sz = `PCKG_SZ);

    int       driver_id;
    trans_bus cola_tx [$];

  	virtual bus_if #(.pckg_sz(pckg_sz)).driver_mp v_bif;
    trans_bus_mbx                       		  drvr_son_mbx;

    function new(
        int                                 		  driver_id,
        virtual bus_if #(.pckg_sz(pckg_sz)).driver_mp v_bif,
        trans_bus_mbx                       		  drvr_son_mbx
    );
        this.driver_id    = driver_id;
        this.v_bif        = v_bif;
        this.drvr_son_mbx = drvr_son_mbx;
    endfunction


    // ── Proceso padre: Inicia al driver hijo
    task run();
        $display("T=%0t [DRIVER_SON %0d] Starting...", $time, driver_id);

        fork
            recibir_del_padre();
            manejar_protocolo();
        join_none
    endtask


    // ── Proceso 1: Se reciben instrucciones y se alimenta la cola TX
    task recibir_del_padre();
        trans_bus trans;

        forever begin
            $display("T=%0t [DRIVER_SON %0d] Waiting for an instruction...", $time, driver_id);

            drvr_son_mbx.get(trans);
            cola_tx.push_back(trans);

            $display("T=%0t [DRIVER_SON %0d] Instruction save in TX queue.", $time, driver_id);
        end
    endtask


    // ── Proceso 2: Manejar protocolo de comunicacion con el DUT (pndng / pop / D_pop)
    task manejar_protocolo();
        int unsigned ciclos_restantes = 0;
        bit          espera_iniciada  = 0;

        forever begin
            if (cola_tx.size() > 0) begin
                if (!espera_iniciada) begin
                    ciclos_restantes = cola_tx[0].delay;
                    espera_iniciada  = 1;
                end

                if (ciclos_restantes > 0) begin
                    v_bif.pndng = 0;
                    v_bif.D_pop = '0;
                end else begin
                    v_bif.pndng = 1;
                    v_bif.D_pop = empaquetar_datos(cola_tx[0]);
                end
            end else begin
                v_bif.pndng = 0;
                v_bif.D_pop = '0;
            end

            @(posedge v_bif.clk);   

            // ── Reduce los ciclos
            if (cola_tx.size() > 0 && ciclos_restantes > 0)
                ciclos_restantes--;

            // ── Manda el paquete si ya no hay ciclos restantes y si se solicita
            if (v_bif.pop && cola_tx.size() > 0 && ciclos_restantes == 0) begin
                $display("T=%0t [DRIVER_SON %0d] Packet sent to DUT.", $time, driver_id);
                void'(cola_tx.pop_front());
                espera_iniciada = 0;
            end
        end
    endtask


    // ── Funcion 1: Empaquetar datos (metadatos y payload)
    function bit [pckg_sz-1:0] empaquetar_datos (trans_bus t);
        empaquetar_datos = {t.id_destino, t.payload};
    endfunction


    // ── Manejar los resets
    task reset();
        @(negedge v_bif.clk);   //<-- Sincroniza con manejar_protocolo().

        v_bif.reset <= 1'b1;
        v_bif.pndng <= 1'b0;
        v_bif.D_pop <= '0;

        cola_tx.delete();

        // ── Esperar a un flanco postiivo
        repeat (1) @(posedge v_bif.clk);

        // ── Desactivar reset
        @(negedge v_bif.clk);
        v_bif.reset <= 1'b0;
    endtask

endclass : Driver_son

`endif // DRIVER_SON_SV

//===================================================================
// Clase Driver_hijo para cada dispositivo del DUT (capa de comando)
//===================================================================
// Conexion al Driver_padre por medio de: drvr_son_mbx
// Tipo de paquetes en el mailbox: trans_bus

class Driver_son #(parameter pckg_sz = 16);

    int driver_id;

    virtual bus_if #(.pckg_sz(pckg_sz)) v_bif;
    mailbox #(trans_bus) drvr_son_mbx;
    trans_bus cola_tx[$];

    function new(
        int                                 driver_id,
        virtual bus_if #(.pckg_sz(pckg_sz)) v_bif,
        mailbox        #(trans_bus)         drvr_son_mbx
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
            $display("T=%0t [DRIVER_SON %0d] Waiting for an instruction...");

            drvr_son_mbx.get(trans);
            cola_tx.push_back(trans);

            $display("T=%0t [DRIVER_SON %0d] Instruction save in TX queue.", $time, driver_id);
        end
    endtask


    // ── Proceso 2: Manejar protocolo de comunicacion con el DUT (pndng / pop / D_pop)
    task manejar_protocolo();
        trans_bus trans;

        forever begin
            v_bif.pndng = (cola_tx.size() > 0);
            v_bif.D_pop = (cola_tx.size() > 0) ? empaquetar_datos(cola_tx[0]) : '0;

            @(posedge v_bif.clk);

            if(v_bif.pop && cola_tx.size() > 0) begin
                $display("T=%0t [DRIVER_SON %0d] Packet sent to DUT.", $time, driver_id);

                void'(cola_tx.pop_front());
            end
        end
    endtask


    // ── Funcion 1: Empaquetar datos (metadatos y payload)
    function bit [pckg_sz-1:0] empaquetar_datos (trans_bus t);
        empaquetar_datos = {t.id_destino, t.payload};
    endfunction

endclass

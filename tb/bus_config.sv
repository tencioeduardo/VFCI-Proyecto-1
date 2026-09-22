//===================================================================
// Clase bus_config para definir tipo de mailbox: trans_bus_mbx
//===================================================================

`ifndef BUS_CONFIG_SV
`define BUS_CONFIG_SV

class bus_config;

    // ----------------------------------------------------------
    // ── Topología del bus
    // ----------------------------------------------------------
    int unsigned         drvrs        = 4;
    bit          [7 : 0] id_invalido  = 8'hD2;
    bit          [7 : 0] id_broadcast = 8'hFF;


    // ----------------------------------------------------------
    // ── Parametros de campos aleatorizables
    // ----------------------------------------------------------
    // ── Pesos del id_destino
    int unsigned wt_destino_valido   = 70;
    int unsigned wt_destino_invalido = 20;
    int unsigned wt_broadcast        = 10;

    // ── Rangos para el delay
    int unsigned min_delay = 0;
    int unsigned max_delay = 5;

    // ── Rangos para el payload
    int unsigned payload_min = 0;
    int unsigned payload_max = 255;


    // ----------------------------------------------------------
    // ── Manejo de constraints en forma de arreglo asociativo
    // ----------------------------------------------------------
    bit cmode [string];

    static string CNAMES[] = '{"destino_dist_c",
                               "dealay_range_c",
                               "origen_range_c",
                               "payload_range_c"};

    // ── Permite verificar si un constraint esta activo
    function bit is_enabled(string cname);
        return cmode.exists(cname) ? cmode[cname] : 1'b1;
    endfunction


    // ----------------------------------------------------------
    // ── Lector de un entero desde la línea de comandos
    // ----------------------------------------------------------
    local function void get_int(string name, ref int unsigned var_);
        int unsigned tmp;
        if ($value$plusargs({name, "=%d"}, tmp)) begin
            var_ = tmp;
            $display("  [CFG] %-22s = %0d (from plusarg)", name, tmp);
        end
    endfunction

    // ── Leer los knobs desde la línea de comandos
    function void parse_plusargs();
        int unsigned en;

        get_int("drvrs",               drvrs);
        get_int("wt_destino_valido",   wt_destino_valido);
        get_int("wt_destino_invalido", wt_destino_invalido);
        get_int("wt_broadcast",        wt_broadcast);
        get_int("min_delay",           min_delay);
        get_int("max_delay",           max_delay);
        get_int("payload_min",         payload_min);
        get_int("payload_max",         payload_max);

        // ── Permite activar o desactivar los constraints: +cm_<nombre>=0/1
        foreach (CNAMES[i]) begin
            en = 1;
            if ($value$plusargs({"cm_", CNAMES[i], "=%d"}, en))
                $display("  [CFG] constraint %-16s -> %s (from plusarg)",
                         CNAMES[i], en[0] ? "ON" : "OFF");
            cmode[CNAMES[i]] = en[0];
        end
    endfunction


    // ----------------------------------------------------------
    // Acceso singleton: Facilita el acceso a config
    // ----------------------------------------------------------
    local static bus_config m_inst;
    static function bus_config get();
        if (m_inst == null) begin
            m_inst = new();
            m_inst.parse_plusargs();
        end
        return m_inst;
    endfunction

endclass : bus_config

`endif // BUS_CONFIG_SV

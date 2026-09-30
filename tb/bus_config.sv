//===================================================================
// Clase bus_config para definir tipo de mailbox: trans_bus_mbx
//===================================================================
`ifndef PCKG_SZ
  `define PCKG_SZ 16  

`endif // PCKG_SZ

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
    // ── Parametros de los escenarios dirigidos del Test
    // ----------------------------------------------------------
    bit          [7 : 0]  broadcast_origen    = 8'd0;
    bit          [7 : 0]  acaparador_origen   = 8'd1;
    bit          [7 : 0]  autoenvio_origen    = 8'd2;
    int unsigned          acaparador_cantidad = 10;
    int unsigned          n_soak              = 20;
    int unsigned          soak_delay          = 2;


    // ----------------------------------------------------------
    // ── Control general del Test
    // ----------------------------------------------------------
    int unsigned timeout       = 20000;   // <-- Ciclos antes de que dispare el watchdog
    int unsigned drain_cycles  = 20;      // <-- Ciclos de espera al final antes de reportar


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

    // ── Igual que get_int, pero con campos de 8 bits (IDs de terminal)
    local function void get_byte(string name, ref bit [7:0] var_);
        int unsigned tmp;
        if ($value$plusargs({name, "=%d"}, tmp)) begin
                var_ = tmp[7:0];
                $display("  [CFG] %-22s = %0d (from plusarg)", name, tmp[7:0]);
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

        get_byte("broadcast_origen",    broadcast_origen);
        get_byte("acaparador_origen",   acaparador_origen);
        get_int ("acaparador_cantidad", acaparador_cantidad);
        get_byte("autoenvio_origen",    autoenvio_origen);
        get_int ("n_soak",              n_soak);
        get_int ("soak_delay",          soak_delay);

        get_int("timeout",       timeout);
        get_int("drain_cycles",  drain_cycles);

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

//============================================
// Clase Checker (capa funcional)
//============================================

//============================================
// Clase Checker (capa funcional)
//============================================
// Recibe esperados del Scoreboard (sb2chk_mbx) y eventos del Monitor
// (mon2chk_mbx). Verifica por contenido TX_POP y RX_PUSH segun el caso.

`ifndef CHECKER_SV
`define CHECKER_SV

class Checker #(parameter pckg_sz = `PCKG_SZ);

    typedef enum {VALID_P2P, SELF_SEND, BROADCAST, INVALID} dest_kind_e;

    trans_bus_mbx mon2chk_mbx;
    trans_bus_mbx sb2chk_mbx;
    bus_config    cfg;

    trans_bus expected_q [$];
    trans_bus rx_q       [$];
    trans_bus tx_q       [$];

    event ev_activity;

    int unsigned n_expected_total         = 0;
    int unsigned n_rx_total               = 0;
    int unsigned n_tx_total               = 0;
    int unsigned n_matches_p2p            = 0;
    int unsigned n_matches_self           = 0;
    int unsigned n_matches_broadcast      = 0;
    int unsigned n_matches_invalid        = 0;
    int unsigned n_mismatches_payload     = 0;
    int unsigned n_missing_tx             = 0;
    int unsigned n_missing_rx             = 0;
    int unsigned n_unexpected_rx          = 0;
    int unsigned n_unexpected_tx          = 0;
    int unsigned n_resets                 = 0;
    // Esperados descartados por EV_RESET.
    int unsigned n_expected_dropped_reset = 0;

    function new(trans_bus_mbx mon2chk_mbx, trans_bus_mbx sb2chk_mbx);
        this.mon2chk_mbx = mon2chk_mbx;
        this.sb2chk_mbx  = sb2chk_mbx;
        this.cfg         = bus_config::get();
    endfunction

    // ── Proceso padre: Inicia el checker
    task run();
        fork
            recibir_scoreboard();
            recibir_monitor();
            matcher();
        join_none
    endtask

    // ── Proceso 1: Recibe esperados del Scoreboard
    task recibir_scoreboard();
        trans_bus t;
        forever begin
            sb2chk_mbx.get(t);
            expected_q.push_back(t);
            n_expected_total++;
            -> ev_activity;
        end
    endtask

    // ── Proceso 2: Recibe eventos del Monitor
    task recibir_monitor();
        trans_bus t;
        forever begin
            mon2chk_mbx.get(t);
            case (t.mon_kind)
                EV_RX_PUSH: begin
                    rx_q.push_back(t);
                    n_rx_total++;
                end
                EV_TX_POP: begin
                    tx_q.push_back(t);
                    n_tx_total++;
                end
                EV_RESET: begin
                    n_expected_dropped_reset += expected_q.size();
                    expected_q.delete();
                    rx_q.delete();
                    tx_q.delete();
                    n_resets++;
                    $display("[CHECKER] Reset detectado: colas limpiadas.");
                end
                default: begin
                    $warning("[CHECKER] Evento de monitor desconocido: mon_kind=%s", t.mon_kind.name());
                end
            endcase
            if (t.mon_kind != EV_RESET) -> ev_activity;
        end
    endtask

    // ── Proceso 3: Dispara el matching
    task matcher();
        forever begin
            @(ev_activity);
            procesar_colas();
        end
    endtask

    task procesar_colas();
        int i;
        i = 0;
        while (i < expected_q.size()) begin
            if (intentar_matchear(expected_q[i]))
                expected_q.delete(i);
            else
                i++;
        end
    endtask

    // ── Clasifica el destino del esperado
    function dest_kind_e clasificar(trans_bus t);
        if (t.id_destino == cfg.id_broadcast)      clasificar = BROADCAST;
        else if (t.id_destino < cfg.drvrs) begin
            if (t.id_destino == t.id_origen)       clasificar = SELF_SEND;
            else                                   clasificar = VALID_P2P;
        end
        else                                        clasificar = INVALID;
    endfunction

    // ── Busqueda exacta en tx_q
    function int buscar_en_tx(bit [7:0] id_origen, bit [7:0] id_destino,
                               bit [pckg_sz-9:0] payload);
        for (int k = 0; k < tx_q.size(); k++) begin
            if (tx_q[k].id_origen  == id_origen  &&
                tx_q[k].id_destino == id_destino &&
                tx_q[k].payload    == payload) return k;
        end
        return -1;
    endfunction

    // ── Busqueda por ruta en tx_q (diagnostico)
    function int buscar_en_tx_por_ruta(bit [7:0] id_origen, bit [7:0] id_destino);
        for (int k = 0; k < tx_q.size(); k++) begin
            if (tx_q[k].id_origen == id_origen && tx_q[k].id_destino == id_destino)
                return k;
        end
        return -1;
    endfunction

    // ── Busqueda exacta en rx_q
    function int buscar_en_rx(bit [7:0] id_destino, bit [pckg_sz-9:0] payload);
        for (int k = 0; k < rx_q.size(); k++) begin
            if (rx_q[k].id_destino == id_destino && rx_q[k].payload == payload)
                return k;
        end
        return -1;
    endfunction

    // ── Busqueda por destino en rx_q (diagnostico)
    function int buscar_en_rx_por_destino(bit [7:0] id_destino);
        for (int k = 0; k < rx_q.size(); k++) begin
            if (rx_q[k].id_destino == id_destino) return k;
        end
        return -1;
    endfunction

    // ── Cuenta RX de broadcast por payload y device_id
    function int contar_rx_broadcast(bit [pckg_sz-9:0] payload, bit [7:0] id_origen,
                                     ref int idxs[$]);
        idxs.delete();
        for (int k = 0; k < rx_q.size(); k++) begin
            if (rx_q[k].id_destino == cfg.id_broadcast &&
                rx_q[k].payload    == payload &&
                rx_q[k].device_id  != id_origen) begin
                bit ya_contado;
                ya_contado = 1'b0;
                foreach (idxs[m]) begin
                    if (rx_q[idxs[m]].device_id == rx_q[k].device_id) ya_contado = 1'b1;
                end
                if (!ya_contado) idxs.push_back(k);
            end
        end
        return idxs.size();
    endfunction

    // ── Logica de matching
    function bit intentar_matchear(trans_bus exp);
        dest_kind_e kind;
        int         tx_idx;
        int         rx_idx;
        int         rx_idxs[$];

        kind = clasificar(exp);

        case (kind)

            VALID_P2P: begin
                // Match exacto TX y RX.
                tx_idx = buscar_en_tx(exp.id_origen, exp.id_destino, exp.payload);
                if (tx_idx == -1) return 1'b0;
                rx_idx = buscar_en_rx(exp.id_destino, exp.payload);
                if (rx_idx == -1) return 1'b0;
                tx_q.delete(tx_idx);
                rx_q.delete(rx_idx);
                n_matches_p2p++;
                return 1'b1;
            end

            SELF_SEND: begin
                // Solo se exige TX_POP.
                tx_idx = buscar_en_tx(exp.id_origen, exp.id_destino, exp.payload);
                if (tx_idx == -1) return 1'b0;
                tx_q.delete(tx_idx);
                n_matches_self++;
                return 1'b1;
            end

            BROADCAST: begin
                tx_idx = buscar_en_tx(exp.id_origen, exp.id_destino, exp.payload);
                if (tx_idx == -1) return 1'b0;

                // N = cfg.drvrs - 1 (sin broadcast-to-self).
                if (contar_rx_broadcast(exp.payload, exp.id_origen, rx_idxs) < (cfg.drvrs - 1)) return 1'b0;

                tx_q.delete(tx_idx);
                rx_idxs.sort();
                for (int m = rx_idxs.size() - 1; m >= 0; m--) rx_q.delete(rx_idxs[m]);
                n_matches_broadcast++;
                return 1'b1;
            end

            INVALID: begin
                tx_idx = buscar_en_tx(exp.id_origen, exp.id_destino, exp.payload);
                if (tx_idx == -1) return 1'b0;
                tx_q.delete(tx_idx);
                n_matches_invalid++;
                // Solo se exige TX_POP; ausencia de RX se valida en wrap_up.
                return 1'b1;
            end

            default: return 1'b0;
        endcase
    endfunction

    // ── Cierre del test
    function void wrap_up();
        int          tx_idx, rx_idx;
        int          idxs[$];
        int          n_recv;
        int unsigned total_contabilizado;
        // Estado por esperado: 0=sin TX exacto, 1=TX sin RX, 2=contabilizado
        int          estado [$];
        dest_kind_e  kind;

        // ── Fase 1: matches exactos
        foreach (expected_q[i]) begin
            kind = clasificar(expected_q[i]);
            estado.push_back(0);

            tx_idx = buscar_en_tx(expected_q[i].id_origen,
                                  expected_q[i].id_destino,
                                  expected_q[i].payload);
            if (tx_idx == -1) continue;
            tx_q.delete(tx_idx);

            case (kind)
                INVALID: begin
                    n_matches_invalid++;
                    estado[i] = 2;
                end

                SELF_SEND: begin
                    n_matches_self++;
                    estado[i] = 2;
                end

                VALID_P2P: begin
                    rx_idx = buscar_en_rx(expected_q[i].id_destino, expected_q[i].payload);
                    if (rx_idx == -1) begin
                        estado[i] = 1;
                    end else begin
                        rx_q.delete(rx_idx);
                        n_matches_p2p++;
                        estado[i] = 2;
                    end
                end

                BROADCAST: begin
                    n_recv = contar_rx_broadcast(expected_q[i].payload,
                                                 expected_q[i].id_origen, idxs);
                    idxs.sort();
                    for (int m = idxs.size() - 1; m >= 0; m--) rx_q.delete(idxs[m]);
                    estado[i] = 2;
                    if (n_recv < cfg.drvrs - 1) begin
                        n_missing_rx++;
                        $error("[CHK-FAIL] Broadcast incompleto para %s (RX=%0d, esperados=%0d)",
                               expected_q[i].convert2str(), n_recv, cfg.drvrs - 1);
                    end else begin
                        n_matches_broadcast++;
                    end
                end

                default: estado[i] = 2;
            endcase
        end

        // ── Fase 2: diagnostico
        foreach (expected_q[i]) begin
            case (estado[i])
                0: begin
                    // Sin TX exacto: buscar TX por ruta.
                    tx_idx = buscar_en_tx_por_ruta(expected_q[i].id_origen,
                                                    expected_q[i].id_destino);
                    if (tx_idx == -1) begin
                        n_missing_tx++;
                        $error("[CHK-FAIL] Falta TX_POP para %s", expected_q[i].convert2str());
                    end else begin
                        // Payload corrupto en TX.
                        n_mismatches_payload++;
                        $error("[CHK-FAIL] Payload corrupto en TX para %s (obtenido=0x%0h)",
                               expected_q[i].convert2str(), tx_q[tx_idx].payload);
                        tx_q.delete(tx_idx);
                    end
                end

                1: begin
                    // TX correcto sin RX exacto: buscar RX por destino.
                    rx_idx = buscar_en_rx_por_destino(expected_q[i].id_destino);
                    if (rx_idx == -1) begin
                        n_missing_rx++;
                        $error("[CHK-FAIL] Falta RX_PUSH para %s", expected_q[i].convert2str());
                    end else begin
                        // Payload corrupto en RX.
                        n_mismatches_payload++;
                        $error("[CHK-FAIL] Payload corrupto TX->RX para %s (recibido=0x%0h)",
                               expected_q[i].convert2str(), rx_q[rx_idx].payload);
                        rx_q.delete(rx_idx);
                    end
                end

                default: ;
            endcase
        end

        n_unexpected_rx = rx_q.size();
        n_unexpected_tx = tx_q.size();

        foreach (rx_q[i]) $warning("[CHK-FAIL] RX_PUSH inesperado: %s", rx_q[i].convert2str());
        foreach (tx_q[i]) $warning("[CHK-FAIL] TX_POP inesperado: %s", tx_q[i].convert2str());

        $display("=====================================================");
        $display("[CHECKER] REPORTE FINAL");
        $display("-----------------------------------------------------");
        $display("  Esperados totales     : %0d", n_expected_total);
        $display("  RX totales observados : %0d", n_rx_total);
        $display("  TX totales observados : %0d", n_tx_total);
        $display("  Resets observados     : %0d", n_resets);
        $display("  Esperados desc. reset : %0d", n_expected_dropped_reset);
        $display("-----------------------------------------------------");
        $display("  Matches P2P           : %0d", n_matches_p2p);
        $display("  Matches Autoenvio     : %0d", n_matches_self);
        $display("  Matches Broadcast     : %0d", n_matches_broadcast);
        $display("  Matches Invalido      : %0d", n_matches_invalid);
        $display("-----------------------------------------------------");
        $display("  Mismatches payload    : %0d", n_mismatches_payload);
        $display("  Missing TX            : %0d", n_missing_tx);
        $display("  Missing RX            : %0d", n_missing_rx);
        $display("  Unexpected RX         : %0d", n_unexpected_rx);
        $display("  Unexpected TX         : %0d", n_unexpected_tx);
        $display("=====================================================");

        total_contabilizado = n_matches_p2p + n_matches_broadcast +
                              n_matches_invalid + n_matches_self +
                              n_mismatches_payload +
                              n_missing_tx + n_missing_rx +
                              n_expected_dropped_reset;

        if (n_expected_total != total_contabilizado) begin
            $error("[CHK-FAIL] Inconsistencia de conteos: esperados=%0d, contabilizados=%0d",
                   n_expected_total, total_contabilizado);
        end

        if (n_mismatches_payload == 0 && n_missing_tx == 0 && n_missing_rx == 0 &&
            n_unexpected_rx == 0 && n_unexpected_tx == 0 &&
            (n_expected_total == total_contabilizado)) begin
            $display(">>> TEST PASSED <<<");
        end else begin
            $display(">>> TEST FAILED <<<");
        end
    endfunction

endclass

`endif // CHECKER_SV

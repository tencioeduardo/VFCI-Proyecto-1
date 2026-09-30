`ifndef CHECKER_SV
`define CHECKER_SV

// -----------------------------------------------------------------
// Checker: recibe transacciones "esperadas" del Scoreboard
// (sb2chk_mbx) y eventos observados del Monitor (mon2chk_mbx,
// EV_RX_PUSH / EV_TX_POP / EV_RESET), y verifica por contenido
// (no por posición ni por orden) que cada esperado tenga su TX_POP
// y, según el caso, su(s) RX_PUSH correspondiente(s).
//
// No compara id_origen en el lado RX (decisión 11): el paquete no
// viaja con el ID de origen, así que el Monitor tampoco lo conoce
// del lado receptor.
// -----------------------------------------------------------------
class Checker #(parameter pckg_sz = 16);

    typedef enum {VALID_P2P, BROADCAST, INVALID} dest_kind_e;

    trans_bus_mbx mon2chk_mbx;
    trans_bus_mbx sb2chk_mbx;
    bus_config    cfg;

    trans_bus expected_q [$];
    trans_bus rx_q       [$];
    trans_bus tx_q       [$];

    event ev_activity;

    int unsigned n_expected_total     = 0;
    int unsigned n_rx_total           = 0;
    int unsigned n_tx_total           = 0;
    int unsigned n_matches_p2p        = 0;
    int unsigned n_matches_broadcast  = 0;
    int unsigned n_matches_invalid    = 0;
    int unsigned n_mismatches_payload = 0;
    int unsigned n_missing_tx         = 0;
    int unsigned n_missing_rx         = 0;
    int unsigned n_unexpected_rx      = 0;
    int unsigned n_unexpected_tx      = 0;
    int unsigned n_resets             = 0;

    function new(trans_bus_mbx mon2chk_mbx, trans_bus_mbx sb2chk_mbx);
        this.mon2chk_mbx = mon2chk_mbx;
        this.sb2chk_mbx  = sb2chk_mbx;
        this.cfg         = bus_config::get();
    endfunction

    task run();
        fork
            recibir_scoreboard();
            recibir_monitor();
            matcher();
        join_none
    endtask

    task recibir_scoreboard();
        trans_bus t;
        forever begin
            sb2chk_mbx.get(t);
            expected_q.push_back(t);
            n_expected_total++;
            -> ev_activity;
        end
    endtask

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

    function dest_kind_e clasificar(trans_bus t);
        if (t.id_destino == cfg.id_broadcast)      clasificar = BROADCAST;
        else if (t.id_destino < cfg.drvrs)         clasificar = VALID_P2P;
        else                                        clasificar = INVALID;
    endfunction

    // -------- Helpers de búsqueda (por contenido, no por índice) ----

    // Búsqueda exacta en tx_q: origen + destino + payload.
    function int buscar_en_tx(bit [7:0] id_origen, bit [7:0] id_destino,
                               bit [pckg_sz-9:0] payload);
        for (int k = 0; k < tx_q.size(); k++) begin
            if (tx_q[k].id_origen  == id_origen  &&
                tx_q[k].id_destino == id_destino &&
                tx_q[k].payload    == payload) return k;
        end
        return -1;
    endfunction

    // Búsqueda "por ruta" en tx_q (solo origen+destino, sin exigir
    // payload). Se usa como diagnóstico de payload corrupto cuando
    // la búsqueda exacta falla.
    function int buscar_en_tx_por_ruta(bit [7:0] id_origen, bit [7:0] id_destino);
        for (int k = 0; k < tx_q.size(); k++) begin
            if (tx_q[k].id_origen == id_origen && tx_q[k].id_destino == id_destino)
                return k;
        end
        return -1;
    endfunction

    // Búsqueda exacta en rx_q: destino + payload (NO compara
    // id_origen, decisión 11).
    function int buscar_en_rx(bit [7:0] id_destino, bit [pckg_sz-9:0] payload);
        for (int k = 0; k < rx_q.size(); k++) begin
            if (rx_q[k].id_destino == id_destino && rx_q[k].payload == payload)
                return k;
        end
        return -1;
    endfunction

    // Búsqueda "por destino" en rx_q, ignorando payload: diagnóstico
    // de payload corrupto en la recepción.
    function int buscar_en_rx_por_destino(bit [7:0] id_destino);
        for (int k = 0; k < rx_q.size(); k++) begin
            if (rx_q[k].id_destino == id_destino) return k;
        end
        return -1;
    endfunction

    // Cuenta cuántos RX_PUSH de broadcast con el payload dado
    // existen en rx_q, contando cada device_id una sola vez.
    // Devuelve también sus índices en idxs (ascendente).
    function int contar_rx_broadcast(bit [pckg_sz-9:0] payload, ref int idxs[$]);
        idxs.delete();
        for (int k = 0; k < rx_q.size(); k++) begin
            if (rx_q[k].id_destino == cfg.id_broadcast && rx_q[k].payload == payload) begin
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

    // -------- Lógica de matching -------------------------------------

    function bit intentar_matchear(trans_bus exp);
        dest_kind_e kind;
        int         tx_idx;
        int         rx_idx;
        int         rx_idxs[$];

        kind = clasificar(exp);

        case (kind)

            VALID_P2P: begin
                tx_idx = buscar_en_tx(exp.id_origen, exp.id_destino, exp.payload);
                if (tx_idx != -1) begin
                    rx_idx = buscar_en_rx(exp.id_destino, exp.payload);
                    if (rx_idx != -1) begin
                        tx_q.delete(tx_idx);
                        rx_q.delete(rx_idx);
                        n_matches_p2p++;
                        return 1'b1;
                    end
                    // TX correcto, ¿llegó ya un RX con payload distinto?
                    rx_idx = buscar_en_rx_por_destino(exp.id_destino);
                    if (rx_idx != -1) begin
                        $error("[CHK-FAIL] Payload corrupto TX->RX: org=%0d dst=%0d esperado=0x%0h recibido=0x%0h",
                               exp.id_origen, exp.id_destino, exp.payload, rx_q[rx_idx].payload);
                        n_mismatches_payload++;
                        tx_q.delete(tx_idx);
                        rx_q.delete(rx_idx);
                        return 1'b1;
                    end
                    return 1'b0; // TX visto, RX aún no llega
                end
                // No hay TX exacto: ¿el DUT emitió un TX con payload corrupto?
                tx_idx = buscar_en_tx_por_ruta(exp.id_origen, exp.id_destino);
                if (tx_idx != -1) begin
                    $error("[CHK-FAIL] Payload corrupto en TX: org=%0d dst=%0d esperado=0x%0h obtenido=0x%0h",
                           exp.id_origen, exp.id_destino, exp.payload, tx_q[tx_idx].payload);
                    n_mismatches_payload++;
                    tx_q.delete(tx_idx);
                    return 1'b1;
                end
                return 1'b0;
            end

            BROADCAST: begin
                tx_idx = buscar_en_tx(exp.id_origen, exp.id_destino, exp.payload);
                if (tx_idx == -1) return 1'b0;

                // SUPUESTO A VALIDAR: N = cfg.drvrs (incluye broadcast-to-self).
                if (contar_rx_broadcast(exp.payload, rx_idxs) < cfg.drvrs) return 1'b0;

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
                // Ausencia de RX se valida en wrap_up (evita falsos
                // positivos por carreras mientras el test aún corre).
                return 1'b1;
            end

            default: return 1'b0;
        endcase
    endfunction

    // -------- Cierre del test -----------------------------------------

    // Declarada como `function` (no `task`): no contiene ningún
    // bloqueo (`@`, `#`, `get()`), así que ejecuta en tiempo cero
    // igual que antes — pero al ser función puede invocarse también
    // desde un bloque `final` del Environment, donde un `task` no
    // compilaría.
    function void wrap_up();
        int         tx_idx, rx_idx;
        dest_kind_e kind;

        foreach (expected_q[i]) begin
            kind   = clasificar(expected_q[i]);
            tx_idx = buscar_en_tx(expected_q[i].id_origen, expected_q[i].id_destino, expected_q[i].payload);
            if (tx_idx == -1)
                tx_idx = buscar_en_tx_por_ruta(expected_q[i].id_origen, expected_q[i].id_destino);
            if (tx_idx == -1) begin
                n_missing_tx++;
                $error("[CHK-FAIL] Falta TX_POP para %s", expected_q[i].convert2str());
            end else begin
                // Ya quedó contabilizado (aunque el match global haya
                // fallado por el lado RX): no debe contar también como
                // "unexpected" al final.
                tx_q.delete(tx_idx);
            end

            if (kind == VALID_P2P || kind == BROADCAST) begin
                rx_idx = buscar_en_rx(expected_q[i].id_destino, expected_q[i].payload);
                if (rx_idx == -1)
                    rx_idx = buscar_en_rx_por_destino(expected_q[i].id_destino);
                if (rx_idx == -1) begin
                    n_missing_rx++;
                    $error("[CHK-FAIL] Falta RX_PUSH para %s", expected_q[i].convert2str());
                end else begin
                    rx_q.delete(rx_idx);
                end
            end
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
        $display("-----------------------------------------------------");
        $display("  Matches P2P           : %0d", n_matches_p2p);
        $display("  Matches Broadcast     : %0d", n_matches_broadcast);
        $display("  Matches Invalido      : %0d", n_matches_invalid);
        $display("-----------------------------------------------------");
        $display("  Mismatches payload    : %0d", n_mismatches_payload);
        $display("  Missing TX            : %0d", n_missing_tx);
        $display("  Missing RX            : %0d", n_missing_rx);
        $display("  Unexpected RX         : %0d", n_unexpected_rx);
        $display("  Unexpected TX         : %0d", n_unexpected_tx);
        $display("=====================================================");

        if (n_mismatches_payload == 0 && n_missing_tx == 0 && n_missing_rx == 0 &&
            n_unexpected_rx == 0 && n_unexpected_tx == 0) begin
            $display(">>> TEST PASSED <<<");
        end else begin
            $display(">>> TEST FAILED <<<");
        end
    endfunction

endclass

`endif // CHECKER_SV
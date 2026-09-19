//============================================
// Clase Driver_controlador (capa de comando)
//============================================
// Conexion al Agente por medio de: agent_drvr_mbx
// Conexion al Driver_hijo por medio de: drvr_son_mbx
// Tipo de paquetes en el mailbox: trans_bus


class Driver_controller #(parameter pckg_sz = 16);
    mailbox #(trans_bus) agent_drvr_mbx;
    mailbox #(trans_bus) drvr_son_mbx;

    Driver_son children[4];

    function new(
    

    );

    endfunction

endclass
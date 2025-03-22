// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Declaración del contrato ServicePayment, encargado de gestionar pagos de servicios.
contract ServicePayment {

    // Estructura que representa un servicio.
    struct Service {
        address client;         // Dirección del cliente que solicita el servicio.
        address provider;       // Dirección del proveedor que realizará el servicio.
        uint256 amount;         // Cantidad de ETH bloqueada para el servicio.
        uint256 deadline;       // Fecha límite para la confirmación del servicio (timestamp).
        bool clientConfirmed;   // Indica si el cliente ha confirmado la realización del servicio.
    }

    // Mapping que asocia cada identificador (ID) con su servicio correspondiente.
    mapping (uint256 => Service) public services;
    
    // Contador para asignar un ID único a cada nuevo servicio creado.
    uint256 private serviceCounter;
    
    // Eventos que se emitirán para notificar acciones importantes dentro del contrato.
    event ServiceCreated(uint256 serviceId, address client, address provider, uint256 amount, uint256 deadline);
    event ServiceCompleted(uint256 serviceId, address provider, uint256 amount);
    event ServiceRefunded(uint256 servideId, address client, uint256 amount);

    /// @notice Crea un nuevo servicio y bloquea ETH en el contrato.
    /// @param provider Dirección del proveedor que realizará el servicio.
    /// @param deadline Fecha límite para la confirmación del servicio (debe ser mayor al timestamp actual).
    function createService(address provider, uint256 deadline) external payable {
        // Verifica que se envíe una cantidad mayor a 0 de ETH.
        require(msg.value > 0, "Debe enviar ETH");
        // Verifica que la dirección del proveedor no sea la dirección cero.
        require(provider != address(0), "Proveedor no valido");
        // Verifica que la fecha límite sea un momento futuro.
        require(deadline > block.timestamp, "Fecha limite invalida");

        // Registra el servicio en el mapping usando el contador actual como ID.
        services[serviceCounter] = Service(msg.sender, provider, msg.value, deadline, false);
        // Emite el evento ServiceCreated para notificar la creación del servicio.
        emit ServiceCreated(serviceCounter, msg.sender, provider, msg.value, deadline);
        // Incrementa el contador para el siguiente servicio.
        serviceCounter++;
    }

    /// @notice Permite al cliente confirmar que el servicio ha sido completado y libera los fondos al proveedor.
    /// @param serviceId Identificador del servicio a confirmar.
    function confirmService(uint256 serviceId) external {
        // Obtiene la información del servicio desde el mapping.
        Service storage service = services[serviceId];

        // Verifica que solo el cliente que creó el servicio pueda confirmar.
        require(msg.sender == service.client, "Solo el cliente puede confirmar");
        // Verifica que el servicio aún no haya sido confirmado.
        require(!service.clientConfirmed, "El servicio ya fue confirmado");

        // Marca el servicio como confirmado.
        service.clientConfirmed = true;
        // Transfiere el monto bloqueado al proveedor.
        payable(service.provider).transfer(service.amount);

        // Emite el evento ServiceCompleted para notificar la finalización del servicio.
        emit ServiceCompleted(serviceId, service.provider, service.amount);
    }

    /// @notice Permite al cliente solicitar un reembolso si el servicio no ha sido confirmado y ha pasado la fecha límite.
    /// @param serviceId Identificador del servicio para el cual se solicita el reembolso.
    function requestRefund(uint256 serviceId) external {
        // Obtiene la información del servicio desde el mapping.
        Service storage service = services[serviceId];
        
        // Verifica que solo el cliente que creó el servicio pueda solicitar el reembolso.
        require(msg.sender == service.client, "Solo el cliente puede reembolsar");
        // Verifica que la fecha límite haya pasado.
        require(block.timestamp > service.deadline, "Aun no ha vencido el plazo");
        // Verifica que el servicio no haya sido confirmado previamente.
        require(!service.clientConfirmed, "El servicio ya fue confirmado");

        // Guarda el monto a reembolsar y actualiza el valor a 0 para evitar doble retiro.
        uint256 refundAmount = service.amount;
        service.amount = 0; // Evita doble retiro
        
        // Transfiere el monto de vuelta al cliente.
        payable(service.client).transfer(refundAmount);

        // Emite el evento ServiceRefunded para notificar que se ha realizado un reembolso.
        emit ServiceRefunded(serviceId, service.client, refundAmount);
    }
}

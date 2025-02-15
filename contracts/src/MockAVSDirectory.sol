// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";

contract MockAVSDirectory {
    IDelegationManager public immutable delegation;
    mapping(address => mapping(address => OperatorAVSRegistrationStatus)) public avsOperatorStatus;
    mapping(address => mapping(bytes32 => bool)) public operatorSaltIsSpent;

    enum OperatorAVSRegistrationStatus {
        UNREGISTERED,
        REGISTERED
    }

    event OperatorAVSRegistrationStatusUpdated(
        address indexed operator,
        address indexed avs,
        OperatorAVSRegistrationStatus status
    );

    constructor(IDelegationManager _delegation) {
        delegation = _delegation;
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external {
        require(
            operatorSignature.expiry >= block.timestamp,
            "MockAVSDirectory.registerOperatorToAVS: operator signature expired"
        );
        require(
            avsOperatorStatus[msg.sender][operator] != OperatorAVSRegistrationStatus.REGISTERED,
            "MockAVSDirectory.registerOperatorToAVS: operator already registered"
        );
        require(
            !operatorSaltIsSpent[operator][operatorSignature.salt],
            "MockAVSDirectory.registerOperatorToAVS: salt already spent"
        );

        // Set the operator as registered
        avsOperatorStatus[msg.sender][operator] = OperatorAVSRegistrationStatus.REGISTERED;

        // Mark the salt as spent
        operatorSaltIsSpent[operator][operatorSignature.salt] = true;

        emit OperatorAVSRegistrationStatusUpdated(operator, msg.sender, OperatorAVSRegistrationStatus.REGISTERED);
    }

    function deregisterOperatorFromAVS(address operator) external {
        require(
            avsOperatorStatus[msg.sender][operator] == OperatorAVSRegistrationStatus.REGISTERED,
            "MockAVSDirectory.deregisterOperatorFromAVS: operator not registered"
        );

        // Set the operator as deregistered
        avsOperatorStatus[msg.sender][operator] = OperatorAVSRegistrationStatus.UNREGISTERED;

        emit OperatorAVSRegistrationStatusUpdated(operator, msg.sender, OperatorAVSRegistrationStatus.UNREGISTERED);
    }
} 
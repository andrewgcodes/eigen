// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

contract MockStakeRegistry is IERC1271Upgradeable, OwnableUpgradeable {
    mapping(address => bool) public operatorRegistered;

    function initialize(address initialOwner) external initializer {
        __Ownable_init();
        _transferOwnership(initialOwner);
    }

    function registerOperator(address operator) external {
        operatorRegistered[operator] = true;
    }

    function deregisterOperator(address operator) external {
        operatorRegistered[operator] = false;
    }

    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signature
    ) external view returns (bytes4) {
        // Always return valid signature for demo
        return IERC1271Upgradeable.isValidSignature.selector;
    }
} 
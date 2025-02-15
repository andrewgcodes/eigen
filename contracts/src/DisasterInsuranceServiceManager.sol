// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ECDSAServiceManagerBase} from "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IDisasterInsuranceServiceManager} from "./IDisasterInsuranceServiceManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";

contract DisasterInsuranceServiceManager is ECDSAServiceManagerBase, IDisasterInsuranceServiceManager {
    using ECDSAUpgradeable for bytes32;

    // State Variables
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => DisasterEvent) public disasters;
    mapping(uint256 => mapping(address => bool)) public operatorValidations;
    mapping(uint256 => uint256) public validationCounts;
    mapping(uint256 => uint256) public policyPremiums;
    
    uint256 public policyCount;
    uint256 public disasterCount;
    uint256 public constant MINIMUM_OPERATORS = 3;
    uint256 public constant BASE_PREMIUM_RATE = 5; // 5% of coverage amount

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager
        )
    {}

    function initialize(
        address initialOwner,
        address _rewardsInitiator
    ) external initializer {
        __ServiceManagerBase_init(initialOwner, _rewardsInitiator);
    }

    function createPolicy(
        uint256 coverageAmount,
        string calldata location,
        DisasterType disasterType
    ) external payable override returns (uint256) {
        require(coverageAmount > 0, "Coverage amount must be greater than 0");
        
        // Calculate premium (5% of coverage amount)
        uint256 premium = (coverageAmount * BASE_PREMIUM_RATE) / 100;
        require(msg.value >= premium, "Insufficient premium payment");

        uint256 policyId = policyCount++;
        
        policies[policyId] = Policy({
            policyholder: msg.sender,
            coverageAmount: coverageAmount,
            premium: premium,
            startBlock: uint32(block.number),
            endBlock: uint32(block.number + 200000), // Roughly 30 days
            location: location,
            disasterType: disasterType,
            active: true
        });

        emit PolicyCreated(policyId, msg.sender, policies[policyId]);
        return policyId;
    }

    function reportDisaster(
        string calldata location,
        DisasterType disasterType,
        uint256 severity
    ) external override returns (uint256) {
        uint256 eventId = disasterCount++;
        
        disasters[eventId] = DisasterEvent({
            location: location,
            disasterType: disasterType,
            severity: severity,
            eventBlock: uint32(block.number),
            validated: false
        });

        emit DisasterReported(eventId, disasters[eventId]);
        return eventId;
    }

    function validateDisaster(
        uint256 eventId,
        bytes memory signature
    ) external override {
        require(eventId < disasterCount, "Invalid event ID");
        require(!operatorValidations[eventId][msg.sender], "Already validated");
        
        DisasterEvent storage disaster = disasters[eventId];
        require(!disaster.validated, "Already fully validated");

        // Verify operator's signature
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                disaster.location,
                uint8(disaster.disasterType),
                disaster.severity,
                disaster.eventBlock
            )
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        require(
            magicValue == ECDSAStakeRegistry(stakeRegistry).isValidSignature(ethSignedMessageHash, signature),
            "Invalid signature"
        );

        operatorValidations[eventId][msg.sender] = true;
        validationCounts[eventId]++;

        if (validationCounts[eventId] >= MINIMUM_OPERATORS) {
            disaster.validated = true;
        }

        emit ClaimValidated(eventId, eventId, msg.sender);
    }

    function processClaim(uint256 policyId, uint256 eventId) external override {
        require(policyId < policyCount, "Invalid policy ID");
        require(eventId < disasterCount, "Invalid event ID");
        
        Policy storage policy = policies[policyId];
        DisasterEvent storage disaster = disasters[eventId];
        
        require(policy.active, "Policy is not active");
        require(disaster.validated, "Disaster not validated");
        require(policy.policyholder == msg.sender, "Not the policyholder");
        require(
            keccak256(bytes(policy.location)) == keccak256(bytes(disaster.location)),
            "Location mismatch"
        );
        require(policy.disasterType == disaster.disasterType, "Disaster type mismatch");
        
        // Process payout
        policy.active = false;
        payable(policy.policyholder).transfer(policy.coverageAmount);
        
        emit ClaimPaid(policyId, policy.policyholder, policy.coverageAmount);
    }

    function cancelPolicy(uint256 policyId) external override {
        require(policyId < policyCount, "Invalid policy ID");
        Policy storage policy = policies[policyId];
        require(policy.policyholder == msg.sender, "Not the policyholder");
        require(policy.active, "Policy not active");
        
        policy.active = false;
        // Return 50% of premium if cancelled
        payable(msg.sender).transfer(policy.premium / 2);
    }

    // View Functions
    function getPolicy(uint256 policyId) external view override returns (Policy memory) {
        require(policyId < policyCount, "Invalid policy ID");
        return policies[policyId];
    }

    function getDisasterEvent(uint256 eventId) external view override returns (DisasterEvent memory) {
        require(eventId < disasterCount, "Invalid event ID");
        return disasters[eventId];
    }

    function getPolicyCount() external view override returns (uint256) {
        return policyCount;
    }

    function getDisasterEventCount() external view override returns (uint256) {
        return disasterCount;
    }
} 
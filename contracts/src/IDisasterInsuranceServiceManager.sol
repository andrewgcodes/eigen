// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IDisasterInsuranceServiceManager {
    // Structs
    struct Policy {
        address policyholder;
        uint256 coverageAmount;
        uint256 premium;
        uint32 startBlock;
        uint32 endBlock;
        string location;
        DisasterType disasterType;
        bool active;
    }

    struct DisasterEvent {
        string location;
        DisasterType disasterType;
        uint256 severity;
        uint32 eventBlock;
        bool validated;
    }

    // Enums
    enum DisasterType { EARTHQUAKE, FLOOD, HURRICANE }

    // Events
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, Policy policy);
    event DisasterReported(uint256 indexed eventId, DisasterEvent disaster);
    event ClaimValidated(uint256 indexed eventId, uint256 indexed policyId, address indexed operator);
    event ClaimPaid(uint256 indexed policyId, address indexed policyholder, uint256 amount);

    // Policy Management
    function createPolicy(
        uint256 coverageAmount,
        string calldata location,
        DisasterType disasterType
    ) external payable returns (uint256 policyId);

    function cancelPolicy(uint256 policyId) external;

    // Disaster Reporting and Validation
    function reportDisaster(
        string calldata location,
        DisasterType disasterType,
        uint256 severity
    ) external returns (uint256 eventId);

    function validateDisaster(
        uint256 eventId,
        bytes memory signature
    ) external;

    // Claims
    function processClaim(uint256 policyId, uint256 eventId) external;

    // View Functions
    function getPolicy(uint256 policyId) external view returns (Policy memory);
    function getDisasterEvent(uint256 eventId) external view returns (DisasterEvent memory);
    function getPolicyCount() external view returns (uint256);
    function getDisasterEventCount() external view returns (uint256);
} 
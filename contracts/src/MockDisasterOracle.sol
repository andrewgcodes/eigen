// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IDisasterInsuranceServiceManager} from "./IDisasterInsuranceServiceManager.sol";

contract MockDisasterOracle {
    address public owner;
    IDisasterInsuranceServiceManager public insuranceManager;

    event DisasterDataUpdated(
        string location,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    );

    constructor(address _insuranceManager) {
        owner = msg.sender;
        insuranceManager = IDisasterInsuranceServiceManager(_insuranceManager);
    }

    // Function to simulate disaster data updates
    function updateDisasterData(
        string calldata location,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    ) external {
        // Report the disaster to the insurance manager
        insuranceManager.reportDisaster(location, disasterType, severity);
        
        emit DisasterDataUpdated(location, disasterType, severity);
    }

    // Thresholds for different disaster types
    function getDisasterThreshold(IDisasterInsuranceServiceManager.DisasterType disasterType) 
        public pure returns (uint256) 
    {
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE) {
            return 60; // 6.0 on Richter scale (multiplied by 10)
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            return 50; // 5.0 meters
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            return 120; // 120 km/h wind speed
        }
        return 0;
    }

    // Check if a disaster warrants a claim
    function isClaimable(
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    ) public pure returns (bool) {
        return severity >= getDisasterThreshold(disasterType);
    }
} 
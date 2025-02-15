// contracts/src/MockRiskAssessmentOracle.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IDisasterInsuranceServiceManager} from "./IDisasterInsuranceServiceManager.sol";

contract MockRiskAssessmentOracle {
    struct RiskProfile {
        uint256 riskScore;        // 0-100
        uint256 recommendedPremiumBps; // basis points
        string riskFactors;
        uint256 maxCoverage;
    }

    // Simulated ML model outputs for different locations
    mapping(bytes32 => RiskProfile) private locationRiskProfiles;

    constructor() {
        // Hardcode some realistic risk profiles
        // San Francisco - High earthquake risk
        locationRiskProfiles[keccak256(bytes("San Francisco"))] = RiskProfile({
            riskScore: 85,
            recommendedPremiumBps: 750, // 7.5%
            riskFactors: "High seismic activity zone, Dense urban area, Historical earthquake data",
            maxCoverage: 100 ether
        });

        // Miami - High hurricane risk
        locationRiskProfiles[keccak256(bytes("Miami"))] = RiskProfile({
            riskScore: 90,
            recommendedPremiumBps: 800, // 8%
            riskFactors: "Coastal location, Hurricane prone zone, Storm surge risk",
            maxCoverage: 80 ether
        });

        // Kansas City - Moderate risk
        locationRiskProfiles[keccak256(bytes("Kansas City"))] = RiskProfile({
            riskScore: 45,
            recommendedPremiumBps: 400, // 4%
            riskFactors: "Tornado alley, Moderate risk zone",
            maxCoverage: 150 ether
        });
    }

    function assessRisk(
        string memory location,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        address userAddress,
        bytes memory additionalData
    ) external view returns (RiskProfile memory) {
        bytes32 locationHash = keccak256(bytes(location));
        
        // Return default profile if location not found
        if (locationRiskProfiles[locationHash].riskScore == 0) {
            return RiskProfile({
                riskScore: 50,
                recommendedPremiumBps: 500, // 5%
                riskFactors: "Default risk profile",
                maxCoverage: 50 ether
            });
        }

        return locationRiskProfiles[locationHash];
    }
}
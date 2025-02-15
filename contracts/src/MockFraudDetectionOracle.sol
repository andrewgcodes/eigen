// contracts/src/MockFraudDetectionOracle.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract MockFraudDetectionOracle {
    struct FraudAnalysis {
        bool suspicious;
        uint256 fraudScore;       // 0-100
        string[] fraudIndicators;
        uint256 confidenceLevel;  // 0-100
    }

    mapping(address => FraudAnalysis) private addressFraudProfiles;

    constructor() {
        // Hardcode some fraud profiles
        // Suspicious address
        address suspiciousAddr = address(0x1234567890123456789012345678901234567890);
        string[] memory indicators = new string[](3);
        indicators[0] = "Multiple rapid claims in short time period";
        indicators[1] = "Inconsistent location data";
        indicators[2] = "Pattern matches known fraud schemes";
        
        addressFraudProfiles[suspiciousAddr] = FraudAnalysis({
            suspicious: true,
            fraudScore: 85,
            fraudIndicators: indicators,
            confidenceLevel: 90
        });
    }

    function analyzeClaim(
        uint256 policyId,
        uint256 eventId,
        address claimant,
        bytes memory claimData
    ) external view returns (FraudAnalysis memory) {
        // Return existing fraud profile if found
        if (addressFraudProfiles[claimant].confidenceLevel > 0) {
            return addressFraudProfiles[claimant];
        }

        // Default to low fraud risk
        string[] memory emptyIndicators = new string[](0);
        return FraudAnalysis({
            suspicious: false,
            fraudScore: 10,
            fraudIndicators: emptyIndicators,
            confidenceLevel: 95
        });
    }
}
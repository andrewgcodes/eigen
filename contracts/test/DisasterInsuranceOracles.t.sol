// contracts/test/DisasterInsuranceOracles.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import {DisasterInsuranceServiceManager} from "../src/DisasterInsuranceServiceManager.sol";
import {MockRiskAssessmentOracle} from "../src/MockRiskAssessmentOracle.sol";
import {MockClaimsReviewOracle} from "../src/MockClaimsReviewOracle.sol";
import {MockFraudDetectionOracle} from "../src/MockFraudDetectionOracle.sol";
import {IDisasterInsuranceServiceManager} from "../src/IDisasterInsuranceServiceManager.sol";

contract DisasterInsuranceOraclesTest is Test {
    MockRiskAssessmentOracle public riskOracle;
    MockClaimsReviewOracle public claimsOracle;
    MockFraudDetectionOracle public fraudOracle;

    function setUp() public {
        riskOracle = new MockRiskAssessmentOracle();
        claimsOracle = new MockClaimsReviewOracle();
        fraudOracle = new MockFraudDetectionOracle();
    }

    function test_RiskAssessment() public {
        // Test San Francisco risk assessment
        MockRiskAssessmentOracle.RiskProfile memory sfProfile = riskOracle.assessRisk(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            address(this),
            ""
        );

        assertEq(sfProfile.riskScore, 85);
        assertEq(sfProfile.recommendedPremiumBps, 750);
        assertEq(sfProfile.maxCoverage, 100 ether);
        
        // Test Miami risk assessment
        MockRiskAssessmentOracle.RiskProfile memory miamiProfile = riskOracle.assessRisk(
            "Miami",
            IDisasterInsuranceServiceManager.DisasterType.HURRICANE,
            address(this),
            ""
        );

        assertEq(miamiProfile.riskScore, 90);
        assertEq(miamiProfile.recommendedPremiumBps, 800);
        assertEq(miamiProfile.maxCoverage, 80 ether);

        // Test default risk assessment
        MockRiskAssessmentOracle.RiskProfile memory defaultProfile = riskOracle.assessRisk(
            "Unknown Location",
            IDisasterInsuranceServiceManager.DisasterType.FLOOD,
            address(this),
            ""
        );

        assertEq(defaultProfile.riskScore, 50);
        assertEq(defaultProfile.recommendedPremiumBps, 500);
        assertEq(defaultProfile.maxCoverage, 50 ether);
    }

    function test_ClaimReview() public {
        // Test valid claim review (ID: 1)
        MockClaimsReviewOracle.ClaimReview memory validReview = claimsOracle.reviewClaim(
            1, // policyId
            1, // eventId
            "" // claimEvidence
        );

        assertTrue(validReview.approved);
        assertEq(validReview.validityScore, 95);
        assertEq(validReview.recommendedPayout, 1 ether);

        // Test partial payout claim (ID: 2)
        MockClaimsReviewOracle.ClaimReview memory partialReview = claimsOracle.reviewClaim(
            2, // policyId
            2, // eventId
            "" // claimEvidence
        );

        assertTrue(partialReview.approved);
        assertEq(partialReview.validityScore, 75);
        assertEq(partialReview.recommendedPayout, 0.7 ether);

        // Test rejected claim (ID: 3)
        MockClaimsReviewOracle.ClaimReview memory rejectedReview = claimsOracle.reviewClaim(
            3, // policyId
            3, // eventId
            "" // claimEvidence
        );

        assertFalse(rejectedReview.approved);
        assertEq(rejectedReview.validityScore, 20);
        assertEq(rejectedReview.recommendedPayout, 0);
    }

    function test_FraudDetection() public {
        // Test known suspicious address
        address suspiciousAddr = address(0x1234567890123456789012345678901234567890);
        MockFraudDetectionOracle.FraudAnalysis memory suspiciousAnalysis = fraudOracle.analyzeClaim(
            1, // policyId
            1, // eventId
            suspiciousAddr,
            "" // claimData
        );

        assertTrue(suspiciousAnalysis.suspicious);
        assertEq(suspiciousAnalysis.fraudScore, 85);
        assertEq(suspiciousAnalysis.confidenceLevel, 90);
        assertEq(suspiciousAnalysis.fraudIndicators.length, 3);

        // Test non-suspicious address
        MockFraudDetectionOracle.FraudAnalysis memory cleanAnalysis = fraudOracle.analyzeClaim(
            1, // policyId
            1, // eventId
            address(this),
            "" // claimData
        );

        assertFalse(cleanAnalysis.suspicious);
        assertEq(cleanAnalysis.fraudScore, 10);
        assertEq(cleanAnalysis.confidenceLevel, 95);
        assertEq(cleanAnalysis.fraudIndicators.length, 0);
    }

    function test_IntegratedClaimProcessing() public {
        // Test full claim processing flow for San Francisco earthquake
        MockRiskAssessmentOracle.RiskProfile memory riskProfile = riskOracle.assessRisk(
            "San Francisco",
            IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE,
            address(this),
            ""
        );

        // Verify risk assessment
        assertEq(riskProfile.riskScore, 85);
        assertEq(riskProfile.recommendedPremiumBps, 750);

        // Review claim
        MockClaimsReviewOracle.ClaimReview memory claimReview = claimsOracle.reviewClaim(
            1,
            1,
            ""
        );

        // Verify claim review
        assertTrue(claimReview.approved);
        assertEq(claimReview.validityScore, 95);

        // Check for fraud
        MockFraudDetectionOracle.FraudAnalysis memory fraudAnalysis = fraudOracle.analyzeClaim(
            1,
            1,
            address(this),
            ""
        );

        // Verify fraud check
        assertFalse(fraudAnalysis.suspicious);
        assertEq(fraudAnalysis.fraudScore, 10);

        // Log full analysis
        console2.log("Risk Score:", riskProfile.riskScore);
        console2.log("Recommended Premium (bps):", riskProfile.recommendedPremiumBps);
        console2.log("Risk Factors:", riskProfile.riskFactors);
        console2.log("Claim Validity Score:", claimReview.validityScore);
        console2.log("Claim Review Reason:", claimReview.reviewReason);
        console2.log("Fraud Score:", fraudAnalysis.fraudScore);
    }
}
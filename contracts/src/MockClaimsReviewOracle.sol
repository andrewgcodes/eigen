// contracts/src/MockClaimsReviewOracle.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract MockClaimsReviewOracle {
    struct ClaimReview {
        bool approved;
        uint256 validityScore;    // 0-100
        string reviewReason;
        uint256 recommendedPayout; // in wei
    }

    // Simulated LLM review responses
    mapping(bytes32 => ClaimReview) private claimReviews;

    constructor() {
        // Hardcode some example claim reviews
        // Valid claim with full payout
        claimReviews[keccak256(abi.encodePacked(uint256(1), uint256(1)))] = ClaimReview({
            approved: true,
            validityScore: 95,
            reviewReason: "Claim verified with multiple data sources. Earthquake damage well documented with photographic evidence. Property damage consistent with reported magnitude.",
            recommendedPayout: 1 ether
        });

        // Partial payout claim
        claimReviews[keccak256(abi.encodePacked(uint256(2), uint256(2)))] = ClaimReview({
            approved: true,
            validityScore: 75,
            reviewReason: "Partial damage verified. Some pre-existing conditions noted. Recommended partial payout based on attributable damage.",
            recommendedPayout: 0.7 ether
        });

        // Rejected claim
        claimReviews[keccak256(abi.encodePacked(uint256(3), uint256(3)))] = ClaimReview({
            approved: false,
            validityScore: 20,
            reviewReason: "Claim documentation insufficient. Reported damage inconsistent with disaster event characteristics.",
            recommendedPayout: 0
        });
    }

    function reviewClaim(
        uint256 policyId,
        uint256 eventId,
        bytes memory claimEvidence
    ) external view returns (ClaimReview memory) {
        bytes32 claimHash = keccak256(abi.encodePacked(policyId, eventId));
        
        // Return default review if not found
        if (claimReviews[claimHash].validityScore == 0) {
            return ClaimReview({
                approved: true,
                validityScore: 80,
                reviewReason: "Standard claim review passed. Documentation appears valid.",
                recommendedPayout: 1 ether
            });
        }

        return claimReviews[claimHash];
    }
}
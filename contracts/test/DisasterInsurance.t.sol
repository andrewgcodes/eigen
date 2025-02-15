// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Test.sol";
import {DisasterInsuranceServiceManager} from "../src/DisasterInsuranceServiceManager.sol";
import {IDisasterInsuranceServiceManager} from "../src/IDisasterInsuranceServiceManager.sol";
import {MockDisasterOracle} from "../src/MockDisasterOracle.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {MockStakeRegistry} from "../src/MockStakeRegistry.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DisasterInsuranceTest is Test {
    DisasterInsuranceServiceManager public insuranceManager;
    MockDisasterOracle public oracle;
    ERC20Mock public token;
    MockStakeRegistry public stakeRegistry;
    address public owner;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        vm.deal(user, 100 ether);

        // Deploy contracts
        stakeRegistry = new MockStakeRegistry();
        stakeRegistry.initialize(owner);

        // Deploy implementation
        DisasterInsuranceServiceManager implementation = new DisasterInsuranceServiceManager(
            address(0), // AVS directory not needed for tests
            address(stakeRegistry),
            address(0), // rewards coordinator not needed for tests
            address(0)  // delegation manager not needed for tests
        );

        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            DisasterInsuranceServiceManager.initialize,
            (owner, owner)
        );
        
        vm.startPrank(owner);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            initData
        );
        insuranceManager = DisasterInsuranceServiceManager(address(proxy));
        vm.stopPrank();

        oracle = new MockDisasterOracle(address(insuranceManager));

        // Register oracle as operator
        vm.startPrank(owner);
        stakeRegistry.registerOperator(address(oracle));
        vm.stopPrank();
    }

    function test_CreatePolicy() public {
        vm.startPrank(user);
        uint256 coverageAmount = 1 ether;
        string memory location = "San Francisco";
        IDisasterInsuranceServiceManager.DisasterType disasterType = IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE;
        
        // Calculate premium (5% of coverage)
        uint256 premium = (coverageAmount * 5) / 100;
        
        uint256 policyId = insuranceManager.createPolicy{value: coverageAmount + premium}(
            coverageAmount,
            location,
            disasterType
        );
        vm.stopPrank();

        IDisasterInsuranceServiceManager.Policy memory policy = insuranceManager.getPolicy(policyId);
        assertEq(policy.policyholder, user);
        assertEq(policy.coverageAmount, coverageAmount);
        assertEq(policy.premium, premium);
        assertEq(policy.location, location);
        assertEq(uint(policy.disasterType), uint(disasterType));
        assertTrue(policy.active);
    }

    function test_DisasterValidation() public {
        // First create a policy
        test_CreatePolicy();

        // Simulate disaster
        string memory location = "San Francisco";
        IDisasterInsuranceServiceManager.DisasterType disasterType = IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE;
        uint256 severity = 70; // 7.0 on Richter scale

        vm.startPrank(owner);
        oracle.updateDisasterData(location, disasterType, severity);
        vm.stopPrank();

        uint256 eventId = insuranceManager.getDisasterEventCount() - 1;
        IDisasterInsuranceServiceManager.DisasterEvent memory disasterEvent = insuranceManager.getDisasterEvent(eventId);
        
        assertEq(disasterEvent.location, location);
        assertEq(uint(disasterEvent.disasterType), uint(disasterType));
        assertEq(disasterEvent.severity, severity);
        assertFalse(disasterEvent.validated);
    }

    function test_ClaimProcessing() public {
        // Create policy and simulate disaster
        test_DisasterValidation();

        uint256 policyId = 0;
        uint256 eventId = 0;

        // Register and validate with multiple operators
        address[] memory operators = new address[](3);
        uint256[] memory privateKeys = new uint256[](3);
        
        // Create test operators
        for (uint i = 0; i < 3; i++) {
            privateKeys[i] = uint256(keccak256(abi.encodePacked("operator", i)));
            operators[i] = vm.addr(privateKeys[i]);
            
            vm.startPrank(owner);
            stakeRegistry.registerOperator(operators[i]);
            vm.stopPrank();

            // Sign and validate
            vm.startPrank(operators[i]);
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    "San Francisco",
                    uint8(IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE),
                    uint256(70),
                    insuranceManager.getDisasterEvent(eventId).eventBlock
                )
            );
            bytes32 ethSignedMessageHash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            insuranceManager.validateDisaster(eventId, signature);
            vm.stopPrank();
        }

        // Process claim
        uint256 userBalanceBefore = user.balance;
        vm.startPrank(user);
        insuranceManager.processClaim(policyId, eventId);
        vm.stopPrank();

        uint256 userBalanceAfter = user.balance;
        assertEq(userBalanceAfter - userBalanceBefore, 1 ether);

        // Check policy is no longer active
        IDisasterInsuranceServiceManager.Policy memory policy = insuranceManager.getPolicy(policyId);
        assertFalse(policy.active);
    }
} 
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {DisasterInsuranceServiceManager} from "../src/DisasterInsuranceServiceManager.sol";
import {IDisasterInsuranceServiceManager} from "../src/IDisasterInsuranceServiceManager.sol";
import {MockDisasterOracle} from "../src/MockDisasterOracle.sol";
import {ERC20Mock} from "../test/ERC20Mock.sol";
import {MockStakeRegistry} from "../src/MockStakeRegistry.sol";
import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";

contract DisasterInsuranceTest is Script {
    DisasterInsuranceServiceManager public insuranceManager;
    MockDisasterOracle public oracle;
    ERC20Mock public token;
    address public operator;
    uint256 public operatorPrivateKey;
    uint256 public ownerPrivateKey;
    MockStakeRegistry public stakeRegistry;

    function setUp() public {
        // Read deployment addresses from JSON
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/disaster-insurance/");
        string memory json = vm.readFile(string.concat(path, vm.toString(block.chainid), ".json"));
        
        // Parse addresses
        address insuranceManagerAddr = abi.decode(vm.parseJson(json, ".addresses.disasterInsuranceServiceManager"), (address));
        address oracleAddr = abi.decode(vm.parseJson(json, ".addresses.mockOracle"), (address));
        address tokenAddr = abi.decode(vm.parseJson(json, ".addresses.token"), (address));
        address stakeRegistryAddr = abi.decode(vm.parseJson(json, ".addresses.stakeRegistry"), (address));
        
        // Initialize contract interfaces
        insuranceManager = DisasterInsuranceServiceManager(insuranceManagerAddr);
        oracle = MockDisasterOracle(oracleAddr);
        token = ERC20Mock(tokenAddr);
        stakeRegistry = MockStakeRegistry(stakeRegistryAddr);

        // Set up operator and owner keys
        operatorPrivateKey = vm.envUint("OPERATOR_KEY");
        operator = vm.addr(operatorPrivateKey);
        ownerPrivateKey = vm.envUint("PRIVATE_KEY"); // Use deployer key as owner
    }

    function registerOperator() public {
        vm.startBroadcast(ownerPrivateKey);
        
        // Create signature data
        bytes32 salt = bytes32(uint256(1)); // Simple salt
        uint256 expiry = block.timestamp + 1 days;
        
        // Create signature struct
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature = ISignatureUtils.SignatureWithSaltAndExpiry({
            signature: new bytes(0), // Empty signature for demo
            salt: salt,
            expiry: expiry
        });
        
        // Register oracle as operator with its own address as signing key
        stakeRegistry.registerOperator(address(oracle));
        
        vm.stopBroadcast();
        console2.log("Registered oracle as operator:", address(oracle));
    }

    function createPolicy() public {
        // Parameters for the policy
        uint256 coverageAmount = 1 ether;
        string memory location = "San Francisco";
        IDisasterInsuranceServiceManager.DisasterType disasterType = IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE;
        
        // Calculate premium (5% of coverage)
        uint256 premium = (coverageAmount * 5) / 100;
        
        vm.startBroadcast();
        // Create policy and send enough ETH to cover the payout
        uint256 policyId = insuranceManager.createPolicy{value: coverageAmount + premium}(
            coverageAmount,
            location,
            disasterType
        );
        vm.stopBroadcast();

        console2.log("Created policy with ID:", policyId);
        
        IDisasterInsuranceServiceManager.Policy memory policy = insuranceManager.getPolicy(policyId);
        console2.log("Policy details:");
        console2.log("Policyholder:", policy.policyholder);
        console2.log("Coverage Amount:", policy.coverageAmount);
        console2.log("Premium:", policy.premium);
        console2.log("Location:", policy.location);
        console2.log("Disaster Type:", uint(policy.disasterType));
    }

    function simulateDisaster() public {
        string memory location = "San Francisco";
        IDisasterInsuranceServiceManager.DisasterType disasterType = IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE;
        uint256 severity = 70; // 7.0 on Richter scale (multiplied by 10)
        
        // First use owner key to update disaster data
        vm.startBroadcast(ownerPrivateKey);
        oracle.updateDisasterData(location, disasterType, severity);
        vm.stopBroadcast();
        
        // Get the latest event ID
        uint256 eventId = insuranceManager.getDisasterEventCount() - 1;
        
        // Register and validate with multiple operators
        address[] memory operators = new address[](3);
        uint256[] memory privateKeys = new uint256[](3);
        
        // Use test private keys for operators
        privateKeys[0] = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        privateKeys[1] = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
        privateKeys[2] = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
        
        for (uint i = 0; i < operators.length; i++) {
            operators[i] = vm.addr(privateKeys[i]);
            
            // Register operator
            vm.startBroadcast(ownerPrivateKey);
            stakeRegistry.registerOperator(operators[i]);
            vm.stopBroadcast();
            
            // Sign and validate the disaster
            vm.startBroadcast(privateKeys[i]);
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    location,
                    uint8(disasterType),
                    severity,
                    insuranceManager.getDisasterEvent(eventId).eventBlock
                )
            );
            bytes32 ethSignedMessageHash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[i], ethSignedMessageHash);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            // Validate the disaster
            insuranceManager.validateDisaster(eventId, signature);
            vm.stopBroadcast();
        }

        console2.log("Simulated disaster with event ID:", eventId);
        
        IDisasterInsuranceServiceManager.DisasterEvent memory disasterEvent = insuranceManager.getDisasterEvent(eventId);
        console2.log("Disaster details:");
        console2.log("Location:", disasterEvent.location);
        console2.log("Type:", uint(disasterEvent.disasterType));
        console2.log("Severity:", disasterEvent.severity);
        console2.log("Validated:", disasterEvent.validated);
    }

    function processClaim() public {
        // Get the latest policy and event IDs
        uint256 policyId = insuranceManager.getPolicyCount() - 1;
        uint256 eventId = insuranceManager.getDisasterEventCount() - 1;

        vm.startBroadcast();
        insuranceManager.processClaim(policyId, eventId);
        vm.stopBroadcast();

        console2.log("Processed claim for policy ID:", policyId);
        console2.log("Event ID:", eventId);
    }
} 
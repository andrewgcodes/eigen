// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/Test.sol";
import {CoreDeploymentLib} from "./utils/CoreDeploymentLib.sol";
import {UpgradeableProxyLib} from "./utils/UpgradeableProxyLib.sol";
import {StrategyBase} from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import {ERC20Mock} from "../test/ERC20Mock.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {StrategyFactory} from "@eigenlayer/contracts/strategies/StrategyFactory.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {Quorum, StrategyParams} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {DisasterInsuranceServiceManager} from "../src/DisasterInsuranceServiceManager.sol";
import {MockStakeRegistry} from "../src/MockStakeRegistry.sol";
import {MockDisasterOracle} from "../src/MockDisasterOracle.sol";
import {MockAVSDirectory} from "../src/MockAVSDirectory.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract DisasterInsuranceDeployer is Script {
    using CoreDeploymentLib for *;
    using UpgradeableProxyLib for address;
    using Strings for address;

    address private deployer;
    address private _proxyAdmin;
    address private _rewardsOwner;
    address private _rewardsInitiator;
    IStrategy private insuranceStrategy;
    CoreDeploymentLib.DeploymentData private coreDeployment;
    Quorum private _quorum;
    ERC20Mock private token;
    MockAVSDirectory private avsDirectory;

    struct DeploymentData {
        address disasterInsuranceServiceManager;
        address stakeRegistry;
        address strategy;
        address token;
        address mockOracle;
        address avsDirectory;
    }

    DeploymentData public deploymentResult;

    function setUp() public virtual {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        vm.label(deployer, "Deployer");
        _rewardsOwner = deployer;
        _rewardsInitiator = deployer;
        coreDeployment = CoreDeploymentLib.readDeploymentJson("deployments/core/", block.chainid);
    }

    function run() external {
        vm.startBroadcast(deployer);

        // Deploy mock token and strategy
        token = new ERC20Mock();
        insuranceStrategy = IStrategy(StrategyFactory(coreDeployment.strategyFactory).deployNewStrategy(token));

        // Set up quorum with strategy
        _quorum.strategies.push(
            StrategyParams({strategy: insuranceStrategy, multiplier: 10_000})
        );

        // Deploy proxy admin
        _proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        // Deploy mock AVS directory
        avsDirectory = new MockAVSDirectory(IDelegationManager(coreDeployment.delegationManager));

        // Deploy contracts
        deploymentResult = deployContracts(
            _proxyAdmin,
            coreDeployment,
            _quorum,
            _rewardsInitiator,
            _rewardsOwner
        );

        vm.stopBroadcast();
        verifyDeployment();
        writeDeploymentJson(deploymentResult);
    }

    function deployContracts(
        address proxyAdmin,
        CoreDeploymentLib.DeploymentData memory core,
        Quorum memory quorum,
        address rewardsInitiator,
        address owner
    ) internal returns (DeploymentData memory) {
        DeploymentData memory result;

        // Deploy proxies
        result.disasterInsuranceServiceManager = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);
        result.stakeRegistry = UpgradeableProxyLib.setUpEmptyProxy(proxyAdmin);

        // Deploy implementations
        address stakeRegistryImpl = address(new MockStakeRegistry());

        address serviceManagerImpl = address(
            new DisasterInsuranceServiceManager(
                address(avsDirectory),
                result.stakeRegistry,
                core.rewardsCoordinator,
                core.delegationManager
            )
        );

        // Initialize contracts
        bytes memory upgradeCall = abi.encodeCall(
            MockStakeRegistry.initialize,
            (owner)
        );
        UpgradeableProxyLib.upgradeAndCall(result.stakeRegistry, stakeRegistryImpl, upgradeCall);

        upgradeCall = abi.encodeCall(
            DisasterInsuranceServiceManager.initialize,
            (owner, rewardsInitiator)
        );
        UpgradeableProxyLib.upgradeAndCall(
            result.disasterInsuranceServiceManager,
            serviceManagerImpl,
            upgradeCall
        );

        // Deploy mock oracle
        result.mockOracle = address(
            new MockDisasterOracle(result.disasterInsuranceServiceManager)
        );

        result.strategy = address(insuranceStrategy);
        result.token = address(token);
        result.avsDirectory = address(avsDirectory);

        return result;
    }

    function verifyDeployment() internal view {
        require(
            deploymentResult.stakeRegistry != address(0),
            "StakeRegistry address cannot be zero"
        );
        require(
            deploymentResult.disasterInsuranceServiceManager != address(0),
            "DisasterInsuranceServiceManager address cannot be zero"
        );
        require(
            deploymentResult.strategy != address(0),
            "Strategy address cannot be zero"
        );
        require(
            deploymentResult.mockOracle != address(0),
            "MockOracle address cannot be zero"
        );
        require(
            deploymentResult.avsDirectory != address(0),
            "AVSDirectory address cannot be zero"
        );
        require(
            _proxyAdmin != address(0),
            "ProxyAdmin address cannot be zero"
        );
    }

    function writeDeploymentJson(DeploymentData memory data) internal {
        string memory jsonData = generateDeploymentJson(data);
        string memory path = "deployments/disaster-insurance/";
        string memory fileName = string.concat(path, vm.toString(block.chainid), ".json");
        
        if (!vm.exists(path)) {
            vm.createDir(path, true);
        }

        vm.writeFile(fileName, jsonData);
        console2.log("Deployment artifacts written to:", fileName);
    }

    function generateDeploymentJson(DeploymentData memory data) internal view returns (string memory) {
        return string.concat(
            '{"lastUpdate":{"timestamp":"',
            vm.toString(block.timestamp),
            '","block_number":"',
            vm.toString(block.number),
            '"},"addresses":',
            generateContractsJson(data),
            "}"
        );
    }

    function generateContractsJson(DeploymentData memory data) internal view returns (string memory) {
        return string.concat(
            '{"proxyAdmin":"',
            Strings.toHexString(uint160(_proxyAdmin), 20),
            '","disasterInsuranceServiceManager":"',
            Strings.toHexString(uint160(data.disasterInsuranceServiceManager), 20),
            '","disasterInsuranceServiceManagerImpl":"',
            Strings.toHexString(uint160(data.disasterInsuranceServiceManager.getImplementation()), 20),
            '","stakeRegistry":"',
            Strings.toHexString(uint160(data.stakeRegistry), 20),
            '","stakeRegistryImpl":"',
            Strings.toHexString(uint160(data.stakeRegistry.getImplementation()), 20),
            '","strategy":"',
            Strings.toHexString(uint160(data.strategy), 20),
            '","token":"',
            Strings.toHexString(uint160(data.token), 20),
            '","mockOracle":"',
            Strings.toHexString(uint160(data.mockOracle), 20),
            '","avsDirectory":"',
            Strings.toHexString(uint160(data.avsDirectory), 20),
            '"}'
        );
    }
} 
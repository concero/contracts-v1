//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.20;
//
//import {Test, console, Vm} from "forge-std/Test.sol";
//import {ParentPool} from "contracts/ParentPool.sol";
//import {ParentPoolCLFCLA} from "contracts/ParentPoolCLFCLA.sol";
//import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
//import {LPToken} from "contracts/LPToken.sol";
//import {CCIPLocalSimulator} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
//import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
//import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
//
//contract BaseTest is Test {
//    /*//////////////////////////////////////////////////////////////
//                               VARIABLES
//    //////////////////////////////////////////////////////////////*/
//    ParentPool public parentPoolImplementation;
//    ParentPoolCLFCLA public parentPoolCLFCLA;
//    TransparentUpgradeableProxy public parentPoolProxy;
//    LPToken public lpToken;
//    FunctionsSubscriptions public functionsSubscriptions;
//    CCIPLocalSimulator public ccipLocalSimulator;
//
//    address user1 = makeAddr("user1");
//    address user2 = makeAddr("user2");
//
//    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
//    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");
//    uint256 internal forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
//    address internal usdc = vm.envAddress("USDC_BASE");
//
//    /*//////////////////////////////////////////////////////////////
//                                 SETUP
//    //////////////////////////////////////////////////////////////*/
//    function setUp() public virtual {
//        vm.selectFork(forkId);
//        deployPoolsInfra();
//    }
//
//    function deployPoolsInfra() public {
//        deployParentPoolProxy();
//        deployLpToken();
//        _deployParentPool();
//        setProxyImplementation(address(parentPoolImplementation));
//        setParentPoolVars();
//        _deployCcipLocalSimulation();
//        addFunctionsConsumer();
//        _fundLinkParentProxy(100000000000000000000);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                              DEPLOYMENTS
//    //////////////////////////////////////////////////////////////*/
//    function deployParentPoolProxy() public {
//        vm.prank(proxyDeployer);
//        parentPoolProxy = new TransparentUpgradeableProxy(
//            vm.envAddress("CONCERO_PAUSE_BASE"),
//            proxyDeployer,
//            bytes("")
//        );
//    }
//
//    function _deployParentPool() private {
//        // Deploy the default ParentPool if no custom address is provided
//        vm.prank(deployer);
//
//        parentPoolCLFCLA = new ParentPoolCLFCLA(
//            address(parentPoolProxy),
//            address(lpToken),
//            vm.envAddress("USDC_BASE"),
//            vm.envAddress("CLF_ROUTER_BASE"),
//            uint64(vm.envUint("CLF_SUBID_BASE")),
//            vm.envBytes32("CLF_DONID_BASE"),
//            address(0x0),
//            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
//        );
//
//        parentPoolImplementation = new ParentPool(
//            address(parentPoolProxy),
//            address(parentPoolCLFCLA),
//            address(0x0),
//            vm.envAddress("LINK_BASE"),
//            vm.envAddress("CL_CCIP_ROUTER_BASE"),
//            vm.envAddress("USDC_BASE"),
//            address(lpToken),
//            vm.envAddress("CONCERO_AUTOMATION_BASE"),
//            vm.envAddress("CONCERO_ORCHESTRATOR_BASE"),
//            vm.envAddress("CLF_ROUTER_BASE"),
//            address(deployer),
//            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
//        );
//    }
//
//    function deployLpToken() public {
//        vm.prank(deployer);
//        lpToken = new LPToken(deployer, address(parentPoolProxy));
//    }
//
//    function _deployCcipLocalSimulation() private {
//        ccipLocalSimulator = new CCIPLocalSimulator();
//        ccipLocalSimulator.configuration();
//        ccipLocalSimulator.supportNewToken(vm.envAddress("USDC_BASE"));
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                                SETTERS
//    //////////////////////////////////////////////////////////////*/
//    function setProxyImplementation(address _parentPoolImplementation) public {
//        vm.prank(proxyDeployer);
//        ITransparentUpgradeableProxy(address(parentPoolProxy)).upgradeToAndCall(
//            _parentPoolImplementation,
//            bytes("")
//        );
//    }
//
//    /// @notice might need to update this to pass _parentPoolImplementation like above
//    function setParentPoolVars() public {
//        vm.prank(deployer);
//        IParentPool(address(parentPoolProxy)).setPools(
//            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
//            address(parentPoolImplementation),
//            false
//        );
//
//        vm.prank(deployer);
//        IParentPool(address(parentPoolProxy)).setConceroContractSender(
//            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
//            address(user1),
//            1
//        );
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                                UTILITY
//    //////////////////////////////////////////////////////////////*/
//    function addFunctionsConsumer() public {
//        vm.prank(vm.envAddress("DEPLOYER_ADDRESS"));
//        functionsSubscriptions = FunctionsSubscriptions(
//            //         TODO: move to env variable
//            address(0xf9B8fc078197181C841c296C876945aaa425B278)
//        );
//        functionsSubscriptions.addConsumer(
//            uint64(vm.envUint("CLF_SUBID_BASE")),
//            address(parentPoolProxy)
//        );
//    }
//
//    function _fundLinkParentProxy(uint256 amount) internal {
//        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), amount);
//    }
//
//    function mintLpToken(address to, uint256 amount) internal {
//        vm.prank(address(parentPoolProxy));
//        lpToken.mint(to, amount);
//    }
//
//    function mintUSDC(address to, uint256 amount) internal {
//        deal(address(vm.envAddress("USDC_BASE")), to, amount);
//    }
//}

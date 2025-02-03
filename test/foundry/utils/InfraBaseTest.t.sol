// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/src/Test.sol";
import {DexSwap} from "contracts/DexSwap.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {PauseDummy} from "contracts/PauseDummy.sol";

contract InfraBaseTest is Test {
    // @notice contract addresses
    TransparentUpgradeableProxy public infraProxy;
    InfraOrchestrator public infraOrchestrator;
    ConceroBridge public conceroBridge;
    DexSwap public dexSwap;

    // @notice helper variables
    address public proxyDeployer = vm.envAddress("PROXY_DEPLOYER");
    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    function deployFullInfra() public {
        deployInfraProxy();
        deployAndSetImplementation();
    }

    function deployAndSetImplementation() public {
        deployDexSwap();
        deployOrchestrator();
    }

    function deployInfraProxy() public {
        vm.prank(proxyDeployer);
        infraProxy = new TransparentUpgradeableProxy(address(new PauseDummy()), proxyDeployer, "");
    }

    function deployDexSwap() public {
        vm.prank(deployer);
        dexSwap = new DexSwap(
            address(infraProxy),
            [vm.envAddress("MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function deployOrchestrator() public {
        vm.prank(deployer);
        infraOrchestrator = new InfraOrchestrator(
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CONCERO_DEX_SWAP_BASE"),
            address(conceroBridge),
            address(0),
            address(infraProxy),
            1,
            [vm.envAddress("MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }
}

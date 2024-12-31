pragma solidity 0.8.20;

import {DeployHelper} from "../utils/DeployHelper.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {DexSwap} from "contracts/DexSwap.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {PauseDummy} from "contracts/PauseDummy.sol";
import {Script} from "forge-std/src/Script.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/src/console.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {InfraStorageSetters} from "contracts/Libraries/InfraStorageSetters.sol";

contract DeployInfraScript is DeployHelper {
    // @notice contract addresses
    TransparentUpgradeableProxy internal infraProxy;
    InfraOrchestrator internal infraOrchestrator;
    ConceroBridge internal conceroBridge;
    DexSwap internal dexSwap;

    // @notice helper variables
    address public proxyDeployer = vm.envAddress("PROXY_DEPLOYER");
    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");
    address[3] public messengers = [vm.envAddress("MESSENGER_0_ADDRESS"), address(0), address(0)];

    function run() public returns (address) {
        _deployFullInfra();
        return address(infraProxy);
    }

    function run(uint256 forkId) public returns (address) {
        vm.selectFork(forkId);
        return run();
    }

    function setProxyImplementation(address implementation) public {
        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(address(infraProxy)).upgradeToAndCall(
            implementation,
            bytes("")
        );
    }

    function getProxy() public view returns (address) {
        return address(infraProxy);
    }

    function _deployFullInfra() internal {
        _deployInfraProxy();
        _deployAndSetImplementation();
        _setInfraVars();
    }

    function _deployInfraProxy() internal {
        vm.prank(proxyDeployer);
        infraProxy = new TransparentUpgradeableProxy(address(new PauseDummy()), proxyDeployer, "");
    }

    function _deployAndSetImplementation() internal {
        _deployDexSwap();
        _deployConceroBridge();
        _deployOrchestrator();

        setProxyImplementation(address(infraOrchestrator));
    }

    function _deployDexSwap() internal {
        vm.prank(deployer);
        dexSwap = new DexSwap(address(infraProxy), messengers);
    }

    function _deployConceroBridge() internal {
        vm.prank(deployer);

        IInfraStorage.FunctionsVariables memory clfVars = IInfraStorage.FunctionsVariables({
            subscriptionId: getCLfSubId(),
            donId: getDonId(),
            functionsRouter: getClfRouter()
        });

        conceroBridge = new ConceroBridge(
            clfVars,
            getChainSelector(),
            getChainIndex(),
            getLinkAddress(),
            getCcipRouter(),
            address(dexSwap),
            address(0),
            address(infraProxy),
            messengers
        );
    }

    function _deployOrchestrator() internal {
        vm.prank(deployer);
        infraOrchestrator = new InfraOrchestrator(
            getClfRouter(),
            address(dexSwap),
            address(conceroBridge),
            address(0),
            address(infraProxy),
            getChainIndex(),
            messengers
        );
    }

    function _setInfraVars() internal {
        _setAllowedDexRouters();
    }

    function _setAllowedDexRouters() internal {
        address[] memory dexRouters = getDexRouters();
        vm.startPrank(deployer);

        for (uint i; i < dexRouters.length; i++) {
            InfraStorageSetters(address(infraProxy)).setDexRouterAddress(dexRouters[i], true);
        }

        vm.stopPrank();
    }
}

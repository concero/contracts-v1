// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/src/Test.sol";
import {ConceroBridgeMock} from "test/foundry/Mocks/ConceroBridgeMock.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON, CHAIN_SELECTOR_ARBITRUM} from "contracts/Constants.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {InfraOrchestratorMock} from "../Mocks/InfraOrchestratorMock.sol";
import {DeployInfraScript} from "../scripts/DeployInfra.s.sol";

contract BridgeTestFees is Test {
    uint256 public constant USDC_DECIMALS = 1e6;

    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    InfraOrchestratorMock internal infraProxy;
    ConceroBridgeMock internal conceroBridge;

    modifier selectForkAndUpdateInfraProxy(uint256 forkId) {
        DeployInfraScript deployInfraScript = new DeployInfraScript();
        infraProxy = InfraOrchestratorMock(payable(deployInfraScript.run(forkId)));
        conceroBridge = deployInfraScript.conceroBridgeMock();

        _setFeesBase(CHAIN_SELECTOR_BASE);
        _setFeesArb(CHAIN_SELECTOR_ARBITRUM);
        _setFeesOpt(CHAIN_SELECTOR_OPTIMISM);
        _setFeesPolygon(CHAIN_SELECTOR_OPTIMISM);
        _;
    }

    function test_ConceroBridgeFeesEqual()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 25989254))
    {
        uint256 amount = 10 * USDC_DECIMALS;
        uint256 oldFees = infraProxy.getSrcTotalFeeInUSDC(
            IInfraStorage.CCIPToken.usdc,
            CHAIN_SELECTOR_OPTIMISM,
            amount
        );

        (uint256 conceroMsgFees, uint256 ccipFees, uint256 lancaFees) = infraProxy
            .getSrcBridgeFeesBreakdownInUsdc(CHAIN_SELECTOR_OPTIMISM, amount);

        uint256 newFees = conceroMsgFees + ccipFees + lancaFees;
        console.log("conceroMsgFees: ", conceroMsgFees);
        console.log("ccipFees: ", ccipFees);
        console.log("lancaFees: ", lancaFees);

        assert(newFees == oldFees);

        console.log("oldFees: ", oldFees);
        console.log("newFees: ", newFees);

        //console.log("getFunctionsFeeInUsdc", infraProxy.getFunctionsFeeInUsdc(CHAIN_SELECTOR_BASE));
    }

    function _setFeesBase(uint64 chainSelector) internal {
        vm.startPrank(deployer);
        //take from our prod contracts
        infraProxy.setClfPremiumFees(chainSelector, 60000000000000000);
        infraProxy.setLastGasPrices(chainSelector, 3453639);

        infraProxy.setLatestNativeUsdcRate(2794546316765254939452);
        infraProxy.setLatestLinkNativeRate(7087070000000000);
        infraProxy.setLatestLinkUsdcRate(19749620609788085970);

        infraProxy.setLastCCIPFeeInLink(chainSelector, 0);
    }

    function _setFeesArb(uint64 chainSelector) internal {
        vm.startPrank(deployer);
        //take from our prod contracts
        infraProxy.setClfPremiumFees(chainSelector, 75000000000000000);
        infraProxy.setLastGasPrices(chainSelector, 3453639);

        infraProxy.setLatestNativeUsdcRate(2794546316765254939452);
        infraProxy.setLatestLinkNativeRate(7087070000000000);
        infraProxy.setLatestLinkUsdcRate(19749620609788085970);

        infraProxy.setLastCCIPFeeInLink(chainSelector, 14965818861893124);
    }

    function _setFeesOpt(uint64 chainSelector) internal {
        vm.startPrank(deployer);
        //take from our prod contracts
        infraProxy.setClfPremiumFees(chainSelector, 80000000000000000);
        infraProxy.setLastGasPrices(chainSelector, 1100409);

        infraProxy.setLatestNativeUsdcRate(2794546316765254939452);
        infraProxy.setLatestLinkNativeRate(7087070000000000);
        infraProxy.setLatestLinkUsdcRate(19749620609788085970);

        infraProxy.setLastCCIPFeeInLink(chainSelector, 11626323072779455);
    }

    function _setFeesPolygon(uint64 chainSelector) internal {
        vm.startPrank(deployer);
        //take from our prod contracts
        infraProxy.setClfPremiumFees(chainSelector, 40000000000000000);
        infraProxy.setLastGasPrices(chainSelector, 9342271);

        infraProxy.setLatestNativeUsdcRate(2794546316765254939452);
        infraProxy.setLatestLinkNativeRate(7087070000000000);
        infraProxy.setLatestLinkUsdcRate(19749620609788085970);

        infraProxy.setLastCCIPFeeInLink(chainSelector, 12373576494025416);
    }
}

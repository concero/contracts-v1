// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/src/Test.sol";
import {ConceroBridgeMock} from "test/foundry/Mocks/ConceroBridgeMock.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_POLYGON} from "contracts/Constants.sol";
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

        _setFees(CHAIN_SELECTOR_POLYGON);
        _setFees(CHAIN_SELECTOR_BASE);
        _;
    }

    function test_ConceroBridgeFeesEqual()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23814899))
    {
        uint256 amount = 10 * USDC_DECIMALS;
        uint256 oldFees = infraProxy.getSrcTotalFeeInUSDC(
            IInfraStorage.CCIPToken.usdc,
            CHAIN_SELECTOR_BASE,
            amount
        );

        (uint256 conceroMsgFees, uint256 ccipFees, uint256 lancaFees) = infraProxy
            .getSrcBridgeFeesBreakdownInUsdc(CHAIN_SELECTOR_BASE, amount);

        uint256 newFees = conceroMsgFees + ccipFees + lancaFees;
        console.log("conceroMsgFees: ", conceroMsgFees);
        console.log("ccipFees: ", ccipFees);
        console.log("lancaFees: ", lancaFees);

        assert(newFees == oldFees);

        console.log("oldFees: ", oldFees);
        console.log("newFees: ", newFees);

        //console.log("getFunctionsFeeInUsdc", infraProxy.getFunctionsFeeInUsdc(CHAIN_SELECTOR_BASE));
    }

    function _setFees(uint64 chainSelector) internal {
        vm.startPrank(deployer);
        //take from our prod contracts
        infraProxy.setClfPremiumFees(chainSelector, 60000000000000000);
        infraProxy.setLastGasPrices(chainSelector, 3480453);

        infraProxy.setLatestNativeUsdcRate(2804643383934286463621);
        infraProxy.setLatestLinkNativeRate(7132975434900616);
        infraProxy.setLatestLinkUsdcRate(20091009336321398309);
        infraProxy.setLastCCIPFeeInLink(chainSelector, 12289774848343018);
    }
}

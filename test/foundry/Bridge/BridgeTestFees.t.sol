// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/src/Test.sol";
import {ConceroBridgeMock} from "test/foundry/Mocks/ConceroBridgeMock.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {CHAIN_SELECTOR_BASE} from "contracts/Constants.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {DeployInfraScript} from "../scripts/DeployInfra.s.sol";

contract BridgeTestFees is Test {
    uint256 public constant USDC_DECIMALS = 1e6;

    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    InfraOrchestrator internal infraProxy;
    ConceroBridgeMock internal conceroBridge;

    modifier selectForkAndUpdateInfraProxy(uint256 forkId) {
        DeployInfraScript deployInfraScript = new DeployInfraScript();
        infraProxy = InfraOrchestrator(payable(deployInfraScript.run(forkId)));
        conceroBridge = deployInfraScript.conceroBridgeMock();

        _setFees(CHAIN_SELECTOR_BASE);
        _;
    }

    function test_ConceroBridgeFeesEqual()
        public
        selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23814899))
    {
        uint256 amount = 1 * USDC_DECIMALS;
        uint256 oldFees = conceroBridge.getSrcTotalFeeInUSDC(CHAIN_SELECTOR_BASE, amount);

        (uint256 conceroMsgFees, uint256 ccipFees, uint256 lancaFees) = conceroBridge
            .getSrcBridgeFeeBreakdown(CHAIN_SELECTOR_BASE, amount);

        uint256 newFees = conceroMsgFees + ccipFees + lancaFees;
        console.log("conceroMsgFees: ", conceroMsgFees);
        console.log("ccipFees: ", ccipFees);
        console.log("lancaFees: ", lancaFees);

        assert(newFees == oldFees);

        console.log("oldFees: ", oldFees);
        console.log("newFees: ", newFees);
    }

    function _setFees(uint64 chainSelector) internal {
        //take from our prod contracts
        conceroBridge.setClfPremiumFees(chainSelector, 60000000000000000);
        conceroBridge.setLastGasPrices(chainSelector, 4611549);

        conceroBridge.setLatestNativeUsdcRate(2728871825713640747152);
        conceroBridge.setLatestLinkNativeRate(7395102713198155);
        conceroBridge.setLatestLinkUsdcRate(20118014974020273024);
        conceroBridge.setLastCCIPFeeInLink(chainSelector, 0.0108225e18);
    }
}

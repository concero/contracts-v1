// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console, stdStorage, StdStorage} from "forge-std/src/Test.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {CHAIN_SELECTOR_POLYGON} from "contracts/Constants.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {DeployInfraScript} from "../scripts/DeployInfra.s.sol";

contract BridgeTestFees is Test {
    using stdStorage for StdStorage;

    uint256 public constant USDC_DECIMALS = 1e6;

    address public deployer = vm.envAddress("DEPLOYER_ADDRESS");

    InfraOrchestrator internal infraProxy;
    ConceroBridge internal conceroBridge;

    modifier selectForkAndUpdateInfraProxy(uint256 forkId) {
        DeployInfraScript deployInfraScript = new DeployInfraScript();
        infraProxy = InfraOrchestrator(payable(deployInfraScript.run(forkId)));
        conceroBridge = ConceroBridge(deployInfraScript.getConceroBridge());

        vm.prank(deployer);
        infraProxy.setClfPremiumFees(CHAIN_SELECTOR_POLYGON, 1e18);
        _;
    }

    function test_feesEqual(
        uint256 amount
    ) public selectForkAndUpdateInfraProxy(vm.createFork(vm.envString("BASE_RPC_URL"), 23814899)) {
        uint256 oldFees = conceroBridge.getSrcTotalFeeInUSDC(CHAIN_SELECTOR_POLYGON, amount);

        (uint256 conceroMsgFees, uint256 ccipFees, uint256 lancaFees) = conceroBridge
            .getSrcBridgeFeeBreakdown(CHAIN_SELECTOR_POLYGON, amount);

        uint256 newFees = conceroMsgFees + ccipFees + lancaFees;

        console.log("oldFees: ", oldFees);
        console.log("newFees: ", newFees);

        assert(newFees == oldFees);
    }
}

//// SPDX-License-Identifier: MIT
//
//pragma solidity 0.8.20;
//
//import {ConceroBridge} from "contracts/ConceroBridge.sol";
//import {BaseTest, console, Vm} from "../utils/BaseTest.t.sol";
//import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
//import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
//import {InfraOrchestratorWrapper} from "./wrappers/InfraOrchestratorWrapper.sol";
//import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
//import {IConceroBridge} from "contracts/Interfaces/IConceroBridge.sol";
//
//contract StartBridge is BaseTest {
//    function setUp() public override {
//        super.setUp();
//
//        (
//            address clfRouter,
//            address dexSwap,
//            address conceroBridge,
//            address pool,
//            address infraProxy,
//            uint8 chainIndex,
//            address[3] memory messengers
//        ) = _getBaseInfraImplementationConstructorArgs();
//
//        _mintLink(address(baseOrchestratorProxy), LINK_INIT_BALANCE);
//
//        vm.prank(deployer);
//        baseOrchestratorImplementation = new InfraOrchestratorWrapper(
//            clfRouter,
//            dexSwap,
//            conceroBridge,
//            pool,
//            infraProxy,
//            chainIndex,
//            messengers
//        );
//
//        _setProxyImplementation(
//            address(baseOrchestratorProxy),
//            address(baseOrchestratorImplementation)
//        );
//
//        _setDstInfraContractsForInfra(
//            address(baseOrchestratorProxy),
//            arbitrumChainSelector,
//            arbitrumOrchestratorProxy
//        );
//
//        _setDstPoolForInfra(
//            address(baseOrchestratorProxy),
//            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
//            arbitrumChildProxy
//        );
//    }
//
//    function test_calculateIntegratorFee(uint256 bridgeAmountBase) public {
//        vm.assume(bridgeAmountBase > 1);
//        vm.assume(bridgeAmountBase < 100000);
//
//        uint256 integratorFeeBase = 3;
//        uint256 bridgeAmount = bridgeAmountBase * 1e18;
//        uint256 integratorFeeBps = integratorFeeBase * 10; // 0.3%
//
//        uint256 fee = InfraOrchestratorWrapper(payable(baseOrchestratorProxy))
//            .calculateIntegratorFee(integratorFeeBps, bridgeAmount);
//
//        uint256 expectedFee = ((bridgeAmount * integratorFeeBase) / 10) / 100;
//
//        assertEq(fee, expectedFee);
//    }
//
//    function test_collectAndWithdrawIntegratorFee(uint256 bridgeAmountBase) public {
//        vm.assume(bridgeAmountBase > 1);
//        vm.assume(bridgeAmountBase < 100000);
//
//        uint256 bridgeAmount = bridgeAmountBase * 1e6;
//        uint256 integratorFeeBase = 2;
//        uint256 integratorFeeBps = integratorFeeBase * 10; // 0.2%
//        address integrator = makeAddr("integrator1");
//
//        // @dev step1: collect integrator fee
//        IInfraOrchestrator.Integration memory integration = IInfraOrchestrator.Integration({
//            integrator: integrator,
//            feeBps: integratorFeeBps
//        });
//
//        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
//            dstChainSelector: arbitrumChainSelector,
//            receiver: makeAddr("receiver1"),
//            amount: bridgeAmount
//        });
//
//        IDexSwap.SwapData[] memory dstSwapData = new IDexSwap.SwapData[](0);
//
//        _mintUSDC(user1, bridgeAmount);
//        _approve(user1, vm.envAddress("USDC_BASE"), address(baseOrchestratorProxy), bridgeAmount);
//
//        vm.prank(user1);
//        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).bridge(
//            bridgeData,
//            dstSwapData,
//            integration
//        );
//
//        uint256 integratorFeeCollected = InfraOrchestratorWrapper(payable(baseOrchestratorProxy))
//            .getCollectedIntegratorFeeByToken(integrator, vm.envAddress("USDC_BASE"));
//
//        assertEq(integratorFeeCollected, ((bridgeAmount * integratorFeeBase) / 10) / 100);
//
//        // @dev step2: withdraw integrator fee
//        uint256 usdcIntegratorBalanceBefore = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
//            integrator
//        );
//        vm.prank(integrator);
//
//        address[] memory tokens = new address[](1);
//        tokens[0] = vm.envAddress("USDC_BASE");
//        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).withdrawIntegratorFees(tokens);
//
//        uint256 usdcIntegratorBalanceAfter = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
//            integrator
//        );
//
//        assertEq(usdcIntegratorBalanceAfter, usdcIntegratorBalanceBefore + integratorFeeCollected);
//
//        // @dev step3: check that integrator fee mapping is cleared
//        integratorFeeCollected = InfraOrchestratorWrapper(payable(baseOrchestratorProxy))
//            .getCollectedIntegratorFeeByToken(integrator, vm.envAddress("USDC_BASE"));
//
//        assertEq(integratorFeeCollected, 0);
//    }
//
//    event ConceroBridgeSent(
//        bytes32 indexed conceroMessageId,
//        IInfraStorage.CCIPToken tokenType,
//        uint256 amount,
//        uint64 dstChainSelector,
//        address receiver,
//        bytes32 dstSwapDataHash
//    );
//
//    function test_txBatchingTrigger() public {
//        uint256 bridgeAmount = 150 * USDC_DECIMALS;
//        address user_1 = makeAddr("user_1");
//        address receiver = makeAddr("receiver_1");
//        IDexSwap.SwapData[] memory dstSwapData = new IDexSwap.SwapData[](0);
//        bytes32 dstSwapDataHash = keccak256(
//            InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).swapDataToBytes(dstSwapData)
//        );
//        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
//            dstChainSelector: arbitrumChainSelector,
//            receiver: receiver,
//            amount: bridgeAmount
//        });
//
//        _mintUSDC(user_1, bridgeAmount);
//        _approve(user_1, vm.envAddress("USDC_BASE"), address(baseOrchestratorProxy), bridgeAmount);
//
//        uint256 userBalanceBefore = IERC20(vm.envAddress("USDC_BASE")).balanceOf(user_1);
//        uint256 infraBalanceBefore = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
//            address(baseOrchestratorProxy)
//        );
//
//        vm.prank(user_1);
//        vm.expectEmit(false, false, false, true, address(baseOrchestratorProxy));
//
//        emit ConceroBridgeSent(
//            bytes32(""),
//            IInfraStorage.CCIPToken.usdc,
//            bridgeAmount,
//            arbitrumChainSelector,
//            receiver,
//            dstSwapDataHash
//        );
//
//        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).bridge(
//            bridgeData,
//            dstSwapData,
//            IInfraOrchestrator.Integration({integrator: address(0), feeBps: 0})
//        );
//
//        uint256 userBalanceAfter = IERC20(vm.envAddress("USDC_BASE")).balanceOf(user_1);
//        uint256 infraBalanceAfter = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
//            address(baseOrchestratorProxy)
//        );
//
//        assertEq(userBalanceAfter, userBalanceBefore - bridgeAmount);
//        assertEq(infraBalanceAfter, infraBalanceBefore + bridgeAmount);
//    }
//
//    function test_sendTxBatch_gas() public {
//        uint256[199] memory amounts;
//        for (uint256 i; i < amounts.length; i++) {
//            amounts[i] = 2 * USDC_DECIMALS;
//        }
//
//        address[] memory users = new address[](amounts.length);
//
//        for (uint256 i; i < users.length; i++) {
//            string memory name = string(abi.encodePacked("user_", i));
//            users[i] = makeAddr(name);
//            vm.prank(users[i]);
//            _mintUSDC(users[i], amounts[i]);
//            _sendBridgeByUser(users[i], amounts[i], arbitrumChainSelector);
//        }
//
//        address user_1 = makeAddr("user_1");
//        uint256 bridgeAmount = 2 * USDC_DECIMALS;
//        _mintUSDC(user_1, bridgeAmount);
//
//        uint256 startGas = gasleft();
//        _sendBridgeByUser(user_1, bridgeAmount, arbitrumChainSelector);
//        uint256 gasUsedForSendCcipBatch = startGas - gasleft();
//
//        console.log("Gas used for send ccip batch: %d", gasUsedForSendCcipBatch);
//    }
//
//    function test_bridgeFee() public {
//        uint256 bridgeAmount = 300 * USDC_DECIMALS;
//        uint256 bridgeAmountToTriggerBatch = 10000 * USDC_DECIMALS;
//
//        _setInfraClfPremiumFeeByChainSelector(
//            address(baseOrchestratorProxy),
//            arbitrumChainSelector,
//            8 * 1e16
//        );
//        _setInfraClfPremiumFeeByChainSelector(
//            address(baseOrchestratorProxy),
//            baseChainSelector,
//            7 * 1e16
//        );
//        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).setLatestLinkUsdcRate(13 * 1e18);
//
//        address user_1 = makeAddr("user_1");
//
//        // @dev send some tx for populating s_lastCcipFeeInLink variable
//        _mintUSDC(user_1, bridgeAmountToTriggerBatch);
//        _sendBridgeByUser(user_1, bridgeAmountToTriggerBatch, arbitrumChainSelector);
//
//        _mintUSDC(user_1, bridgeAmount);
//        _sendBridgeByUser(user_1, bridgeAmount, arbitrumChainSelector);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                               UTILS
//    //////////////////////////////////////////////////////////////*/
//
//    function _sendBridgeByUser(
//        address user,
//        uint256 bridgeAmount,
//        uint64 dstChainSelector
//    ) internal {
//        IDexSwap.SwapData[] memory dstSwapData = new IDexSwap.SwapData[](0);
//        IInfraOrchestrator.Integration memory integration = IInfraOrchestrator.Integration({
//            integrator: address(0),
//            feeBps: 0
//        });
//        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
//            dstChainSelector: dstChainSelector,
//            receiver: user,
//            amount: bridgeAmount
//        });
//
//        _approve(user, vm.envAddress("USDC_BASE"), address(baseOrchestratorProxy), bridgeAmount);
//
//        vm.prank(user);
//        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).bridge(
//            bridgeData,
//            dstSwapData,
//            integration
//        );
//    }
//}

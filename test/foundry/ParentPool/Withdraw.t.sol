// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {VmSafe} from "forge-std/src/Vm.sol";
import {BaseTest, console} from "../utils/BaseTest.t.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsCoordinator, FunctionsBillingConfig} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {FunctionsRouter, IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {ICCIP} from "contracts/Interfaces/ICCIP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {LPToken} from "contracts/LPToken.sol";
import {ParentPoolWrapper} from "./wrappers/ParentPoolWrapper.sol";
import {ParentPool} from "contracts/ParentPool.sol";
import {ParentPoolCLFCLA} from "contracts/ParentPoolCLFCLA.sol";

contract WithdrawTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
     //////////////////////////////////////////////////////////////*/
    address internal liquidityProvider = makeAddr("liquidityProvider");
    ParentPoolWrapper internal parentPoolImplementationWrapper;

    uint256 internal constant LP_BALANCE_USDC = 100 * USDC_DECIMALS;
    uint256 internal constant LP_BALANCE_LPT = 100 ether;
    uint256 internal constant CHILD_POOLS_LIQUIDITY_USDC = 200_000 * USDC_DECIMALS;
    uint256 internal constant PARENT_POOL_LIQUIDITY_USDC = 100_000 * USDC_DECIMALS;
    uint256 internal constant TOTAL_LPT_MINTED = 300_000 ether;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
     //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(baseForkId);
        deployParentPoolProxy();
        deployLpToken();

        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];

        vm.startPrank(deployer);

        parentPoolCLFCLA = new ParentPoolCLFCLA(
            address(parentPoolProxy),
            address(lpToken),
            vm.envAddress("USDC_BASE"),
            vm.envAddress("CLF_ROUTER_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            vm.envBytes32("CLF_DONID_BASE"),
            messengers
        );

        parentPoolImplementationWrapper = new ParentPoolWrapper(
            address(parentPoolProxy),
            address(parentPoolCLFCLA),
            vm.envAddress("PARENT_POOL_AUTOMATION_FORWARDER_BASE_SEPOLIA"),
            vm.envAddress("LINK_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            address(baseOrchestratorProxy),
            vm.envAddress("CLF_ROUTER_BASE"),
            address(deployer),
            messengers
        );

        vm.stopPrank();

        addFunctionsConsumer(address(parentPoolProxy));

        _setProxyImplementation(address(parentPoolProxy), address(parentPoolImplementationWrapper));
        _mintLpToken(liquidityProvider, LP_BALANCE_LPT);
        _mintLpToken(makeAddr("0x0001"), TOTAL_LPT_MINTED - LP_BALANCE_LPT);

        _deployChildPoolsAndSetToParentPool();
    }

    /*//////////////////////////////////////////////////////////////
                             START WITHDRAWAL
     //////////////////////////////////////////////////////////////*/
    function test_startWithdrawal() public {
        uint256 lptAmountToBurn = 2 ether;

        vm.startPrank(liquidityProvider);
        IERC20(lpToken).approve(address(parentPoolProxy), lptAmountToBurn);
        ParentPool(payable(parentPoolProxy)).startWithdrawal(lptAmountToBurn);
        vm.stopPrank();

        // Assert remaining balance
        uint256 expectedRemainingBalance = LP_BALANCE_LPT - lptAmountToBurn;
        assertEq(IERC20(lpToken).balanceOf(liquidityProvider), expectedRemainingBalance);

        // Get withdrawal ID and assert
        bytes32 withdrawalId = ParentPool(payable(parentPoolProxy)).getWithdrawalIdByLPAddress(
            liquidityProvider
        );
        assert(withdrawalId != 0);

        // Get withdrawal request params
        (
            address lpAddress,
            uint256 lpAmountToBurn,
            uint256 amountReadyToWithdrawUSDC
        ) = ParentPoolWrapper(payable(parentPoolProxy)).getWithdrawRequestParams(withdrawalId);

        // Assert withdrawal params
        assertEq(lpAddress, liquidityProvider);
        assertEq(lpAmountToBurn, lptAmountToBurn);
        assertEq(amountReadyToWithdrawUSDC, 0);
    }

    function test_startWithdrawalRevertsIfZeroLpAmount() public {
        vm.prank(liquidityProvider);
        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountBelowMinimum(uint256)", 1 ether));
        ParentPool(payable(parentPoolProxy)).startWithdrawal(0);
    }

    function test_startWithdrawalRevertsIfRequestAlreadyActive() public {
        vm.startPrank(liquidityProvider);
        IERC20(lpToken).approve(address(parentPoolProxy), LP_BALANCE_LPT);

        ParentPool(payable(parentPoolProxy)).startWithdrawal(LP_BALANCE_LPT);

        /// @dev call again, expecting revert
        vm.expectRevert(abi.encodeWithSignature("WithdrawalRequestAlreadyExists()"));
        ParentPool(payable(parentPoolProxy)).startWithdrawal(LP_BALANCE_LPT);
    }

    function test_completeWithdrawal() public {
        _mintUSDC(address(parentPoolProxy), PARENT_POOL_LIQUIDITY_USDC);

        bytes32 withdrawRequestId = _startWithdrawal(LP_BALANCE_LPT, liquidityProvider);

        IParentPool.WithdrawRequest memory withdrawalRequest = ParentPoolWrapper(
            payable(parentPoolProxy)
        ).getWithdrawalRequest(withdrawRequestId);

        ICCIP.CcipTxData memory ccipTxData = ICCIP.CcipTxData({
            ccipTxType: ICCIP.CcipTxType.withdrawal,
            data: abi.encode(withdrawRequestId)
        });
        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: vm.envAddress("USDC_BASE"),
            amount: withdrawalRequest.remainingLiquidityFromChildPools / 2
        });
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked(withdrawRequestId, arbitrumChainSelector)),
            sourceChainSelector: arbitrumChainSelector,
            sender: abi.encode(address(arbitrumChildProxy)),
            data: abi.encode(ccipTxData),
            destTokenAmounts: destTokenAmounts
        });

        uint256 lpUsdcBalanceBefore = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
            liquidityProvider
        );
        _prankCcipReceive(address(parentPoolProxy), message);

        message.sourceChainSelector = avalancheChainSelector;
        message.sender = abi.encode(address(avalancheChildProxy));
        message.messageId = keccak256(abi.encodePacked(withdrawRequestId, avalancheChainSelector));

        _prankCcipReceive(address(parentPoolProxy), message);

        uint256 lpUsdcBalanceAfter = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
            liquidityProvider
        );

        IParentPool.WithdrawRequest memory request = ParentPoolWrapper(payable(parentPoolProxy))
            .getWithdrawalRequest(withdrawRequestId);

        assertEq(lpUsdcBalanceAfter - lpUsdcBalanceBefore, LP_BALANCE_USDC);
    }

    /*//////////////////////////////////////////////////////////////
		                         UTILS
     //////////////////////////////////////////////////////////////*/

    function _startWithdrawal(uint256 lpAmountToWithdraw, address lp) internal returns (bytes32) {
        vm.recordLogs();

        vm.startPrank(lp);
        IERC20(lpToken).approve(address(parentPoolProxy), LP_BALANCE_LPT);
        ParentPool(payable(parentPoolProxy)).startWithdrawal(lpAmountToWithdraw);
        vm.stopPrank();

        VmSafe.Log[] memory logs = vm.getRecordedLogs();

        bytes32 withdrawRequestId;
        bytes32 clfRequestId;

        // 100_000,_000_000

        for (uint256 i; i < logs.length; i++) {
            bytes32 topic = logs[i].topics[0];
            if (topic == keccak256("WithdrawalRequestInitiated(bytes32,address,uint256)")) {
                withdrawRequestId = logs[i].topics[1];
            } else if (
                topic ==
                keccak256(
                    "RequestStart(bytes32,bytes32,uint64,address,address,address,bytes,uint16,uint32,uint96)"
                )
            ) {
                clfRequestId = logs[i].topics[1];
            }
        }

        if (withdrawRequestId == bytes32(0)) {
            revert("Withdrawal request not initiated");
        }

        _fulfillRequest(clfRequestId, abi.encode(CHILD_POOLS_LIQUIDITY_USDC));

        return withdrawRequestId;
    }

    function _fulfillRequest(bytes32 requestId, bytes memory response) internal {
        vm.prank(vm.envAddress("CLF_ROUTER_BASE"));
        FunctionsClient(address(parentPoolProxy)).handleOracleFulfillment(requestId, response, "");
    }

    function _prankCcipReceive(address receiver, Client.Any2EVMMessage memory message) internal {
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));
        IAny2EVMMessageReceiver(receiver).ccipReceive(message);
    }
}

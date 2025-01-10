// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BaseTest} from "../../utils/BaseTest.t.sol";
import {Test, console, Vm} from "forge-std/src/Test.sol";
import {ParentPoolWrapper} from "../wrappers/ParentPoolWrapper.sol";
import {ParentPool} from "contracts/ParentPool.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract CalculateLpTokensToMintTest is BaseTest {
    uint256 internal constant LP_DECIMALS = 10 ** 18;

    /*//////////////////////////////////////////////////////////////
								SETUP
   //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(baseForkId);
        deployParentPoolProxy();
        deployLpToken();

        parentPoolImplementation = new ParentPoolWrapper(
            address(parentPoolProxy),
            address(parentPoolCLFCLA),
            address(0),
            vm.envAddress("LINK_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            address(baseOrchestratorProxy),
            vm.envAddress("CLF_ROUTER_BASE"),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

        _setProxyImplementation(address(parentPoolProxy), address(parentPoolImplementation));
        _setParentPoolVars();
        addFunctionsConsumer(address(parentPoolProxy));
    }

    /*/////////////////////////////////////////////////////////////
       						    TESTS
    /////////////////////////////////////////////////////////////*/

    function test_CalculateLpTokensToMint_DepositInPurePool() public {
        uint256 totalCrossChainBalanceUSDC = 0;
        uint256 childPoolBalanceUSDC = 0;
        uint256 amountToDepositUSDC = 200_000_000;
        uint256 expectedLpAmountToMint = 200 ether;

        uint256 lpAmountToMint = ParentPool(payable(parentPoolProxy)).calculateLPTokensToMint(
            childPoolBalanceUSDC,
            amountToDepositUSDC
        );

        require(lpAmountToMint == expectedLpAmountToMint, "Incorrect LP amount calculated");
    }

    function test_CalculateLpTokensToMint_DepositInPoolWithDepositsOnTheWay() public {
        uint256 totalCrossChainBalanceBody = 3000;
        uint256 totalCrossChainBalanceUSDC = totalCrossChainBalanceBody * USDC_DECIMALS;
        uint256 amountToDepositUSDC = 100 * USDC_DECIMALS;
        uint256 childPoolsCount = 3;
        uint256 expectedLpAmountToMint = 100 ether;
        uint256 prevDepositAmountUSDC = 100 * USDC_DECIMALS;
        uint256 lpTokenAmount = totalCrossChainBalanceBody * LP_DECIMALS;
        uint256 childPoolsBalanceUSDC = _setupPoolsAndLpToken(
            totalCrossChainBalanceUSDC,
            lpTokenAmount,
            prevDepositAmountUSDC
        );

        uint256 lpAmountToMint = ParentPool(payable(parentPoolProxy)).calculateLPTokensToMint(
            childPoolsBalanceUSDC,
            amountToDepositUSDC
        );

        require(lpAmountToMint == expectedLpAmountToMint, "Incorrect LP amount calculated");
    }

    function test_CalculateLpTokensToMint_DepositInPoolWithFees() public {
        uint256 totalCrossChainBalanceBody = 94_000;
        uint256 feesEarnedBody = 400;
        uint256 totalCrossChainBalanceUSDC = (totalCrossChainBalanceBody + feesEarnedBody) *
            USDC_DECIMALS;
        uint256 amountToDepositUSDC = 100 * USDC_DECIMALS;
        uint256 childPoolsCount = 3;
        uint256 expectedLpAmountToMint = 99576271186440677966;
        uint256 lpTokenAmount = totalCrossChainBalanceBody * LP_DECIMALS;
        uint256 childPoolsBalanceUSDC = _setupPoolsAndLpToken(
            totalCrossChainBalanceUSDC,
            lpTokenAmount,
            0
        );

        uint256 lpAmountToMint = ParentPool(payable(parentPoolProxy)).calculateLPTokensToMint(
            childPoolsBalanceUSDC,
            amountToDepositUSDC
        );

        require(lpAmountToMint == expectedLpAmountToMint, "Incorrect LP amount calculated");
    }

    /*///////////////////////////////////////
					HELPERS
	///////////////////////////////////////*/

    function _mintLpToken(uint256 amount, address receiver) private {
        vm.prank(address(parentPoolProxy));
        lpToken.mint(receiver, amount);
    }

    function _USDCToLpDecimals(uint256 amount) private returns (uint256) {
        return (amount * LP_DECIMALS) / USDC_DECIMALS;
    }

    function _simulateParentPoolDepositOnTheWay(uint256 amount, uint256 childPoolsCount) internal {
        for (uint256 i = 0; i < childPoolsCount; i++) {
            ParentPoolWrapper(payable(parentPoolProxy)).addDepositOnTheWay(
                bytes32(uint256(1)),
                uint64(i),
                amount / (childPoolsCount + 1)
            );
        }
    }

    function _simulatePoolsBalanceUSDC(
        uint256 totalCrossChainBalanceUSDC,
        uint256 depositOnTheWayAmountUSDC
    ) internal returns (uint256) {
        address usdc = vm.envAddress("USDC_BASE");
        uint256 depositsOnTheWayAmount = ParentPool(payable(parentPoolProxy))
            .s_depositsOnTheWayAmount();
        uint256 childPoolsBalanceUSDC = ((totalCrossChainBalanceUSDC - depositOnTheWayAmountUSDC) *
            3) / 4;
        uint256 parentPoolBalanceUSDC = totalCrossChainBalanceUSDC -
            childPoolsBalanceUSDC -
            depositsOnTheWayAmount;

        deal(usdc, address(parentPoolProxy), parentPoolBalanceUSDC);

        return childPoolsBalanceUSDC;
    }

    function _setupPoolsAndLpToken(
        uint256 crossChainBalanceUSDC,
        uint256 lpTokenAmount,
        uint256 depositOnTheWatAmount
    ) internal returns (uint256) {
        _mintLpToken((lpTokenAmount), makeAddr("1"));
        return _simulatePoolsBalanceUSDC(crossChainBalanceUSDC, depositOnTheWatAmount);
    }
}

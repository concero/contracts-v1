// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/Interfaces/IParentPool.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {BaseTest, console, Vm} from "../utils/BaseTest.t.sol";
//import {Client} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {FunctionsCoordinator, FunctionsBillingConfig} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
//import {IAny2EVMMessageReceiver} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ParentPoolWrapper, IParentPoolWrapper} from "./wrappers/ParentPoolWrapper.sol";
import {ParentPoolCLFCLA} from "contracts/ParentPoolCLFCLA.sol";
import {ParentPool} from "contracts/ParentPool.sol";

contract Deposit is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant DEPOSIT_AMOUNT_USDC = 100 * 10 ** 6;
    uint256 internal constant MIN_DEPOSIT = 1 * 1_000_000;
    /// @dev transmitter address retrieved from coordinator logs
    address internal constant BASE_FUNCTIONS_TRANSMITTER =
        0xAdE50D64476177aAe4505DFEA094B1a0ffa49332;
    uint256 internal constant CCIP_FEES = 10 * 1e18;
    uint256 internal constant WAD_PRECISION = 1e18;
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * 10 ** 6;
    uint256 internal constant MAX_INDIVIDUAL_DEPOSIT = 100_000 * 1e6; // 100k usdc

    FunctionsRouter internal functionsRouter = FunctionsRouter(vm.envAddress("CLF_ROUTER_BASE"));

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(baseForkId);
        deployParentPoolProxy();
        deployLpToken();

        parentPoolCLFCLA = new ParentPoolCLFCLA(
            address(parentPoolProxy),
            address(lpToken),
            vm.envAddress("USDC_BASE"),
            vm.envAddress("CLF_ROUTER_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            vm.envBytes32("CLF_DONID_BASE"),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

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

    /*//////////////////////////////////////////////////////////////
                             START DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function test_startDeposit_success() public {
        bytes32 requestId = _startDeposit(user1, DEPOSIT_AMOUNT_USDC);

        // Verify storage changes using the requestId
        ParentPoolWrapper.DepositRequest memory depositRequest = IParentPoolWrapper(
            address(parentPoolProxy)
        ).getDepositRequest(requestId);

        assertEq(depositRequest.lpAddress, address(user1));
        assertEq(depositRequest.usdcAmountToDeposit, DEPOSIT_AMOUNT_USDC);
    }

    function _startDeposit(address lp, uint256 amount) internal returns (bytes32) {
        vm.prank(lp);
        vm.recordLogs();

        IParentPoolWrapper(address(parentPoolProxy)).startDeposit(amount);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].topics[0] ==
                keccak256("DepositInitiated(bytes32,address,uint256,uint256)")
            ) {
                return entries[i].topics[1];
            }
        }

        revert("DepositInitiated log not found");
    }

    function test_startDeposit_RevertOnMinDeposit(uint256 _amount) public {
        vm.assume(_amount < MIN_DEPOSIT);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("DepositAmountBelowMinimum(uint256)", MIN_DEPOSIT));
        IParentPoolWrapper(address(parentPoolProxy)).startDeposit(_amount);
    }

    function test_startDeposit_RevertNonProxyCall(address _caller) public {
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "NotParentPoolProxy(address)",
                address(parentPoolImplementation)
            )
        );
        parentPoolImplementation.startDeposit(DEPOSIT_AMOUNT_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                            COMPLETE DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function test_completeDeposit_success() public {
        address usdc = vm.envAddress("USDC_BASE");
        deal(usdc, user1, DEPOSIT_AMOUNT_USDC);
        vm.prank(user1);
        IERC20(usdc).approve(address(parentPoolProxy), DEPOSIT_AMOUNT_USDC);

        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), CCIP_FEES);

        bytes32 depositRequestId = _startDeposit(user1, DEPOSIT_AMOUNT_USDC);

        _fulfillRequest(abi.encode(MIN_DEPOSIT), depositRequestId);

        _completeDeposit(user1, depositRequestId);

        /// @dev assert lp tokens minted as expected
        uint256 expectedLpTokensMinted = ((DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC) *
            WAD_PRECISION) / USDC_DECIMALS;
        uint256 actualLpTokensMinted = IERC20(parentPoolImplementation.i_lpToken()).balanceOf(
            user1
        );
        assertEq(expectedLpTokensMinted, actualLpTokensMinted);

        /// @dev assert storage has been deleted
        ParentPoolWrapper.DepositRequest memory depositRequest = IParentPoolWrapper(
            address(parentPoolProxy)
        ).getDepositRequest(depositRequestId);
        assertEq(depositRequest.lpAddress, address(0));
        assertEq(depositRequest.usdcAmountToDeposit, 0);
    }

    /*//////////////////////////////////////////////////////////////
									 UTILS
		//////////////////////////////////////////////////////////////*/

    function _completeDeposit(address lp, bytes32 requestId) internal {
        /// @dev call completeDeposit via proxy
        vm.prank(lp);
        (bool success, ) = address(parentPoolProxy).call(
            abi.encodeWithSignature("completeDeposit(bytes32)", requestId)
        );
        require(success, "completeDeposit call failed");
    }

    function _fulfillRequest(bytes memory response, bytes32 requestId) internal {
        vm.prank(vm.envAddress("CLF_ROUTER_BASE"));
        FunctionsClient(address(parentPoolProxy)).handleOracleFulfillment(requestId, response, "");
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {console, Vm} from "forge-std/Test.sol";
import {BridgeBaseTest} from "./BridgeBaseTest.t.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {LibZip} from "solady/src/utils/LibZip.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {FunctionsRouter, IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {FunctionsCoordinator, FunctionsBillingConfig} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeCompressionTest is BridgeBaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 constant USER_FUNDS = 1_000_000;
    bytes encodedDstSwapData;
    bytes compressedDstSwapData;
    address usdcAvalanche = vm.envAddress("USDC_AVALANCHE");
    address constant DAI_AVALANCHE = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    address constant CLF_TRANSMITTER_AVALANCHE = 0x88793C4E85aa6dDE4A84864B834Fe64DD6e1Bf94;
    uint256 constant TO_AMOUNT = USER_FUNDS / 2;
    uint256 constant STANDARD_TOKEN_DECIMALS = 1_000_000_000_000_000_000; // 18 decimals

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        BridgeBaseTest.setUp();

        //        _setStorageVars();
        _dealUsdcAndApprove(user1, USER_FUNDS);
        _dealLinkToProxy(STANDARD_TOKEN_DECIMALS * 10);
    }

    /*//////////////////////////////////////////////////////////////
                             LIBZIP COMPRESSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_emptySwapData_validateCompression() public {
        // empty array, uncompressed: 0x00
        // empty array, compressed: 0xffff
        IDexSwap.SwapData[] memory emptySwapData = new IDexSwap.SwapData[](0);
        //        encodedDstSwapData = _swapDataToBytes(originalSwapData);
        //        bytes memory customData = abi.encode(uint16(0x11), encodedDstSwapData);
        bytes memory encodedData = abi.encode(emptySwapData);
        console.logBytes(encodedData);

        compressedDstSwapData = LibZip.cdCompress(encodedData);
        console.logBytes(compressedDstSwapData);

        bytes memory uncompressedDstSwapData = LibZip.cdDecompress(compressedDstSwapData);
        console.logBytes(uncompressedDstSwapData);

        assertEq(encodedData, uncompressedDstSwapData, "Empty array compression failed");
    }

    function test_calldataCompression_validateDecompression() public {
        IDexSwap.SwapData[] memory originalSwapData = _createDstSwapData();
        encodedDstSwapData = _swapDataToBytes(originalSwapData);
        compressedDstSwapData = LibZip.cdCompress(encodedDstSwapData);
        bytes memory decompressedData = LibZip.cdDecompress(compressedDstSwapData);
        IDexSwap.SwapData[] memory decompressedSwapData = abi.decode(
            decompressedData,
            (IDexSwap.SwapData[])
        );
        assertEq(
            decompressedSwapData.length,
            originalSwapData.length,
            "Decompressed length mismatch"
        );

        for (uint256 i = 0; i < originalSwapData.length; i++) {
            assertEq(
                decompressedSwapData[i].fromToken,
                originalSwapData[i].fromToken,
                "FromToken mismatch"
            );
            assertEq(
                decompressedSwapData[i].toToken,
                originalSwapData[i].toToken,
                "ToToken mismatch"
            );
            assertEq(
                decompressedSwapData[i].fromAmount,
                originalSwapData[i].fromAmount,
                "FromAmount mismatch"
            );
            assertEq(
                decompressedSwapData[i].toAmount,
                originalSwapData[i].toAmount,
                "ToAmount mismatch"
            );
            assertEq(
                decompressedSwapData[i].toAmountMin,
                originalSwapData[i].toAmountMin,
                "ToAmountMin mismatch"
            );
            assertEq(
                decompressedSwapData[i].dexData,
                originalSwapData[i].dexData,
                "DexData mismatch"
            );
        }
    }

    //    /*//////////////////////////////////////////////////////////////
    //                             DECOMPRESSION
    //    //////////////////////////////////////////////////////////////*/
    //    /// @dev fromToken needs to be usdc address on dst chain!
    //    /// anvil --fork-url https://rpc.ankr.com/avalanche --port 8546
    //    function test_calldataCompression_dstSwap_decompression() public {
    //        /// @dev create dstSwapData
    //        IDexSwap.SwapData[] memory dstSwapData = _createDstSwapData();
    //
    //        /// @dev encode and compress dstSwapData (simulating what happens before and during CLF)
    //        encodedDstSwapData = _swapDataToBytes(dstSwapData);
    //        compressedDstSwapData = LibZip.cdCompress(encodedDstSwapData);
    //
    //        bytes32 conceroMessageId = keccak256(
    //            abi.encodePacked(user1, user1, USER_FUNDS, block.timestamp)
    //        );
    //
    //        //        /// @dev fork avalanche mainnet and deploy infra contracts
    //        //        vm.selectFork(avalancheFork);
    //        //        _deployAvalancheInfra();
    //
    //        /// @dev prank messenger to call addUnconfirmedTX
    //        vm.recordLogs();
    //        vm.prank(messenger);
    //        (bool success, ) = address(baseOrchestratorProxy).call(
    //            abi.encodeWithSignature(
    //                "addUnconfirmedTX(bytes32,address,address,uint256,uint64,uint8,uint256,bytes)",
    //                conceroMessageId,
    //                user1,
    //                user1,
    //                USER_FUNDS,
    //                baseChainSelector,
    //                IInfraStorage.CCIPToken.usdc,
    //                block.timestamp,
    //                compressedDstSwapData
    //            )
    //        );
    //        require(success, "addUnconfirmedTX delegate call failed");
    //
    //                /// @dev get the clfRequestId, callbackGasLimit and estimatedTotalCostJuels
    //                bytes32 clfRequestId;
    //                uint32 callbackGasLimit;
    //                uint96 estimatedTotalCostJuels;
    //                Vm.Log[] memory logs = vm.getRecordedLogs();
    //                bytes32 eventSignature = keccak256(
    //                    "RequestStart(bytes32,bytes32,uint64,address,address,address,bytes,uint16,uint32,uint96)"
    //                );
    //                for (uint256 i = 0; i < logs.length; i++) {
    //                    if (logs[i].topics[0] == eventSignature) {
    //                        clfRequestId = logs[i].topics[1];
    //
    //                        (, , , , , callbackGasLimit, estimatedTotalCostJuels) = abi.decode(
    //                            logs[i].data,
    //                            (address, address, address, bytes, uint16, uint32, uint96)
    //                        );
    //                    }
    //                }

    //        /// @dev check storage has updated with the correctly compressed data
    //        (, bytes memory retData) = address(avalancheOrchestratorProxy).call(
    //            abi.encodeWithSignature("getTransaction(bytes32)", conceroMessageId)
    //        );
    //        IInfraStorage.Transaction memory transaction = abi.decode(
    //            retData,
    //            (IInfraStorage.Transaction)
    //        );
    //        bytes memory dstSwapDataInStorage = transaction.dstSwapData;
    //        bytes memory decompressedDstSwapData = LibZip.cdDecompress(dstSwapDataInStorage);
    //        assertEq(dstSwapDataInStorage, compressedDstSwapData);
    //        assertEq(encodedDstSwapData, decompressedDstSwapData);
    //
    //        /// @dev make sure the child pool has funds to facilitate tx and allow the uni router on avalanche
    //        deal(usdcAvalanche, address(avalancheChildProxy), USER_FUNDS * 10);
    //        _allowUniV3Avalanche();
    //
    //        uint256 toBalanceBefore = IERC20(DAI_AVALANCHE).balanceOf(user1);
    //
    //        /// @dev prank CLF fulfillRequest
    //        _fulfillRequest(clfRequestId, callbackGasLimit, estimatedTotalCostJuels);
    //
    //        /// @dev assert swap successful
    //        uint256 toTokenBalance = IERC20(DAI_AVALANCHE).balanceOf(user1);
    //        assertGe(toTokenBalance, TO_AMOUNT);
    //        assertEq(toBalanceBefore, 0);
    //        vm.stopPrank();
    //    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _swapDataToBytes(
        IDexSwap.SwapData[] memory _swapData
    ) internal pure returns (bytes memory _encodedData) {
        if (_swapData.length == 0) {
            _encodedData = new bytes(1);
        } else {
            _encodedData = abi.encode(_swapData);
        }
    }

    function _createDstSwapData() internal returns (IDexSwap.SwapData[] memory) {
        address routerAddress = UNI_V3_ROUTER_AVALANCHE;
        uint24 fee = 3000;
        uint160 sqrtPriceLimitX96 = 0;
        uint256 deadline = block.timestamp + 3600;
        bytes memory dexData = abi.encode(routerAddress, fee, sqrtPriceLimitX96, deadline);

        IDexSwap.SwapData[] memory _dstSwapData = new IDexSwap.SwapData[](1);
        IDexSwap.SwapData memory singleSwap = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: usdcAvalanche,
            fromAmount: USER_FUNDS / 2,
            toToken: DAI_AVALANCHE,
            toAmount: TO_AMOUNT,
            toAmountMin: USER_FUNDS / 3,
            dexData: dexData
        });
        _dstSwapData[0] = singleSwap;

        return _dstSwapData;
    }

    function _fulfillRequest(
        bytes32 _requestId,
        uint32 _callbackGasLimit,
        uint96 _estimatedTotalCostJuels
    ) internal {
        FunctionsRouter functionsRouter = FunctionsRouter(vm.envAddress("CLF_ROUTER_AVALANCHE"));
        /// @dev get coordinator to call functions router
        address coordinator = functionsRouter.getContractById(vm.envBytes32("CLF_DONID_AVALANCHE"));

        /// @dev create fulfill params
        bytes memory response = abi.encode(1); // we dont use the response in this usecase
        bytes memory err = "";
        uint96 juelsPerGas = 1_000_000_000;
        uint96 costWithoutFulfillment = 0;

        /// @dev get adminFee from the config
        FunctionsRouter.Config memory config = functionsRouter.getConfig();
        uint72 adminFee = config.adminFee;
        /// @dev get timeoutTimestamp from billing config
        FunctionsBillingConfig memory billingConfig = FunctionsCoordinator(coordinator).getConfig();
        uint32 timeoutTimestamp = uint32(block.timestamp + billingConfig.requestTimeoutSeconds);

        /// @notice some of these values have been hardcoded, directly from the logs
        /// @dev create the commitment params
        FunctionsResponse.Commitment memory commitment = FunctionsResponse.Commitment(
            _requestId,
            coordinator,
            _estimatedTotalCostJuels,
            address(avalancheOrchestratorProxy), // client
            uint64(vm.envUint("CLF_SUBID_AVALANCHE")),
            _callbackGasLimit,
            adminFee, // adminFee
            0, // donFee
            133000, // gasOverheadBeforeCallback
            57000, // gasOverheadAfterCallback
            timeoutTimestamp // timeoutTimestamp
        );

        /// @dev prank the coordinator to call fulfill on functionsRouter
        vm.prank(coordinator);
        (FunctionsResponse.FulfillResult resultCode, uint96 callbackGasCostJuels) = functionsRouter
            .fulfill(
                response,
                err,
                juelsPerGas,
                costWithoutFulfillment,
                CLF_TRANSMITTER_AVALANCHE,
                commitment
            );
        vm.stopPrank();
    }

    function _allowUniV3Avalanche() internal {
        vm.prank(deployer);
        (bool success2, ) = address(avalancheOrchestratorProxy).call(
            abi.encodeWithSignature(
                "setDexRouterAddress(address,uint256)",
                UNI_V3_ROUTER_AVALANCHE,
                1
            )
        );
        vm.stopPrank();
    }

    // {
    //     /// @dev startBridge and record logs to get messageId
    //     vm.recordLogs();
    //     // _startBridgeWithDstSwapData(user1, USER_FUNDS, avalancheChainSelector, dstSwapData);
    //     bytes32 messageId;
    //     Vm.Log[] memory logs = vm.getRecordedLogs();
    //     bytes32 eventSignature = keccak256(
    //         "ConceroBridgeSent(bytes32,uint8,uint256,uint64,address,bytes32)"
    //     );
    //     for (uint256 i = 0; i < logs.length; i++) {
    //         if (logs[i].topics[0] == eventSignature) {
    //             messageId = logs[i].topics[0];
    //         }
    //     }
    //     uint256 blockNumber = block.timestamp;

    // }
}

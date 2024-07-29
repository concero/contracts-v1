// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IDexSwap} from "./IDexSwap.sol";
import {IStorage} from "./IStorage.sol";

interface IConceroBridge is IStorage {
    function startBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external;

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    function getSrcTotalFeeInUSDC(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);

    function addUnconfirmedTX(
        bytes32 ccipMessageId,
        address sender,
        address recipient,
        uint256 amount,
        uint64 srcChainSelector,
        CCIPToken token,
        uint256 blockNumber,
        bytes calldata dstSwapData
    ) external;
}
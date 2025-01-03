// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IInfraStorage} from "./IInfraStorage.sol";

interface IConceroBridge is IInfraStorage {
    struct CcipSettlementTx {
        bytes32 id;
        uint256 amount;
        address recipient;
    }

    /// @notice event emitted when an individual tx is sent through CLF
    event ConceroBridgeSent(
        bytes32 indexed conceroMessageId,
        uint256 amount,
        uint64 dstChainSelector,
        address receiver,
        bytes compressedDstSwapData
    );

    /// @notice event emitted when a batched CCIP message is sent
    event ConceroSettlementSent(bytes32 indexed ccipMessageId, uint256 amount);

    /**
     * @notice Function responsible to trigger CCIP and start the bridging process
     * @param bridgeData The bytes data payload with transaction infos
     * @param compressedDstSwapData The bytes data payload with destination swap Data
     * @dev compressedDstSwapData can be empty if there is no swap on destination
     * @dev this function should only be able to called thought infra Proxy
     */
    function bridge(
        BridgeData memory bridgeData,
        bytes calldata compressedDstSwapData
    ) external payable;

    //todo: rename this function to getTotalBridgeFeeUSDC
    /**
     * @notice Function to get the total bridge fee in USDC
     * @param dstChainSelector the destination chain selector
     * @param amount the amount to be bridged
     * @return the total fee in USDC
     */
    function getSrcTotalFeeInUSDC(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @notice Function to get the total amount of fees in USDC
     * @param dstChainSelector the destination blockchain chain selector
     * @param amount the amount to calculate the fees for
     * @return clfFees the amount of Chainlink functions fees in USDC
     * @return ccipFees the amount of CCIP fees in USDC
     * @return conceroFees the amount of Concero fees in USDC
     */
    function getFees(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256 clfFees, uint256 ccipFees, uint256 conceroFees);
}

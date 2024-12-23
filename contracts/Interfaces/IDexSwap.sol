// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IDexSwap {
    /// @notice Concero Struct to track DEX Data
    /// @param dexRouter address of the DEX Router
    /// @param fromToken address of the token to be swapped
    /// @param fromAmount amount of token to be swapped
    /// @param toToken address of the token to be received
    /// @param toAmount amount of token to be received
    /// @param toAmountMin minimum amount of token to be received
    /// @param dexCallData encoded data for the DEX
    struct SwapData {
        address dexRouter;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 toAmount;
        uint256 toAmountMin;
        bytes dexCallData;
    }

    /**
     * @notice Entry point function for the Orchestrator to take loans
     * @param _swapData a struct array that contains dex information.
     * @dev only the Orchestrator contract should be able to call this function
     */
    function entrypoint(
        SwapData[] memory _swapData,
        address _recipient
    ) external payable returns (uint256);
}

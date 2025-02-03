// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IParentPoolViewViaDelegate {
    function calculateLpAmountViaDelegate(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external returns (uint256);
}

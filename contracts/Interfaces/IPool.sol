// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IPool {
    /* FUNCTIONS */
    function takeLoan(address _token, uint256 _amount, address _receiver) external payable;
}

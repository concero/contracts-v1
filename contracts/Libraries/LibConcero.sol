// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibConcero {
    using SafeERC20 for IERC20;

    error TransferToNullAddress();
    error NativeTokenIsNotERC20();
    error UnableToCompleteDelegateCall(bytes data);
    error InvalidAddress();

    function getBalance(address _token, address _contract) internal view returns (uint256) {
        if (_token == address(0)) {
            return address(_contract).balance;
        } else {
            return IERC20(_token).balanceOf(_contract);
        }
    }

    function transferERC20(address token, uint256 amount, address recipient) internal {
        if (token == address(0)) {
            revert NativeTokenIsNotERC20();
        }

        if (recipient == address(0)) {
            revert TransferToNullAddress();
        }

        IERC20(token).safeTransfer(recipient, amount);
    }

    function transferFromERC20(address token, address from, address to, uint256 amount) internal {
        if (token == address(0)) {
            revert NativeTokenIsNotERC20();
        }

        if (to == address(0)) {
            revert TransferToNullAddress();
        }

        IERC20(token).safeTransferFrom(from, to, amount);
    }

    // @dev Safe delegate call to target contract
    // @notice This function is used to call a function in another contract
    // @notice This function should be forever internal. Never expose it to the public
    // @param target The address of the contract to call
    // @param args The data to send to the target contract

    function safeDelegateCall(address target, bytes memory args) internal returns (bytes memory) {
        if (target == address(0)) {
            revert InvalidAddress();
        }

        (bool success, bytes memory response) = target.delegatecall(args);
        if (!success) {
            revert UnableToCompleteDelegateCall(args);
        }

        return response;
    }
}

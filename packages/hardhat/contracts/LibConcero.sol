// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibConcero {
  using SafeERC20 for IERC20;

  error TransferToNullAddress();
  error NativeTokenIsNotERC20();
  // TODO: find way to reuse this error
  error InsufficientBalance(uint256 balance, uint256 amount);

  function getBalance(address _token, address _contract) internal view returns (uint256) {
    if (_token == address(0)) {
      return _contract.balance;
    } else {
      return IERC20(_token).balanceOf(_contract);
    }
  }

  function isNativeToken(address _token) internal pure returns (bool) {
    return _token == address(0);
  }

  function transferERC20(address token, uint256 amount, address recipient) internal {
    if (isNativeToken(token)) {
      revert NativeTokenIsNotERC20();
    }

    if (recipient == address(0)) {
      revert TransferToNullAddress();
    }

    uint256 balance = getBalance(token, address(this));
    if (balance < amount) {
      revert InsufficientBalance(balance, amount);
    }

    IERC20(token).safeTransfer(recipient, amount);
  }
}

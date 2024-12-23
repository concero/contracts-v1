// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {InfraStorage} from "./Libraries/InfraStorage.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {InfraCommon} from "./InfraCommon.sol";

/* ERRORS */
///@notice error emitted when the caller is not allowed
error OnlyProxyContext(address caller);
///@notice error emitted when the swap data is empty
error EmptyDexData();
///@notice error emitted when the router is not allowed
error DexRouterNotAllowed();
///@notice error emitted when the path to swaps is invalid
error InvalidTokenPath();
///@notice error emitted when the DexData is not valid
error InvalidDexData();
///@notice error emitted when the amount is not sufficient
error InsufficientAmount(uint256 amount);
///@notice error emitted when the transfer failed
error TransferFailed();
error SwapFailed();

contract DexSwap is IDexSwap, InfraCommon, InfraStorage {
    using SafeERC20 for IERC20;

    /* IMMUTABLE VARIABLES */
    address private immutable i_proxy;

    /* EVENTS */
    event ConceroSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount,
        address receiver
    );

    constructor(address _proxy, address[3] memory _messengers) InfraCommon(_messengers) {
        i_proxy = _proxy;
    }

    function entrypoint(
        IDexSwap.SwapData[] memory swapData,
        address recipient
    ) external payable returns (uint256) {
        if (address(this) != i_proxy) revert OnlyProxyContext(address(this));

        uint256 swapDataLength = swapData.length;
        address dstToken = swapData[swapDataLength - 1].toToken;
        uint256 addressThisBalanceBefore = LibConcero.getBalance(dstToken, address(this));
        uint256 balanceAfter;

        for (uint256 i; i < swapDataLength; ++i) {
            uint256 balanceBefore = LibConcero.getBalance(swapData[i].toToken, address(this));

            _performSwap(swapData[i]);

            balanceAfter = LibConcero.getBalance(swapData[i].toToken, address(this));
            uint256 tokenReceived = balanceAfter - balanceBefore;

            if (tokenReceived < swapData[i].toAmountMin) {
                revert InsufficientAmount(tokenReceived);
            }

            if (i < swapDataLength - 1) {
                if (swapData[i].toToken != swapData[i + 1].fromToken) {
                    revert InvalidTokenPath();
                }

                swapData[i + 1].fromAmount = tokenReceived;
            }
        }

        if (balanceAfter == 0) {
            revert InvalidDexData();
        }

        uint256 dstTokenReceived = balanceAfter - addressThisBalanceBefore;

        if (recipient != address(this)) {
            _transferTokenToUser(recipient, dstToken, dstTokenReceived);
        }

        emit ConceroSwap(
            swapData[0].fromToken,
            dstToken,
            swapData[0].fromAmount,
            dstTokenReceived,
            recipient
        );

        return dstTokenReceived;
    }

    function _performSwap(IDexSwap.SwapData memory swapData) private {
        if (swapData.dexCallData.length == 0) revert EmptyDexData();

        address routerAddress = swapData.dexRouter;
        if (!s_routerAllowed[routerAddress]) revert DexRouterNotAllowed();

        uint256 fromAmount = swapData.fromAmount;
        bool isFromNative = swapData.fromToken == address(0);

        bool success;
        if (isFromNative) {
            (success, ) = routerAddress.call{value: fromAmount}(swapData.dexCallData);
        } else {
            IERC20(swapData.fromToken).safeIncreaseAllowance(routerAddress, fromAmount);
            (success, ) = routerAddress.call(swapData.dexCallData);
        }

        if (!success) {
            revert SwapFailed();
        }
    }

    function _transferTokenToUser(address recipient, address token, uint256 amount) internal {
        if (amount == 0 || recipient == address(0)) {
            revert InvalidDexData();
        }

        if (token == address(0)) {
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) {
                revert TransferFailed();
            }
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }
}

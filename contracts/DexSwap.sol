// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InfraCommon} from "./InfraCommon.sol";
import {InfraStorage} from "./Libraries/InfraStorage.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* DEPRECATED INTERFACES */
import {ISwapRouter02, IV3SwapRouter} from "./Interfaces/ISwapRouter02.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH} from "./Interfaces/IWETH.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

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
        uint256 lastSwapStepIndex = swapDataLength - 1;
        address dstToken = swapData[lastSwapStepIndex].toToken;
        uint256 dstTokenProxyInitialBalance = LibConcero.getBalance(dstToken, address(this));
        uint256 balanceAfter;

        for (uint256 i; i < swapDataLength; ++i) {
            uint256 balanceBefore = LibConcero.getBalance(swapData[i].toToken, address(this));

            _performSwap(swapData[i]);

            balanceAfter = LibConcero.getBalance(swapData[i].toToken, address(this));
            uint256 tokenReceived = balanceAfter - balanceBefore;

            if (tokenReceived < swapData[i].toAmountMin) {
                revert InsufficientAmount(tokenReceived);
            }

            if (i < lastSwapStepIndex) {
                if (swapData[i].toToken != swapData[i + 1].fromToken) {
                    revert InvalidTokenPath();
                }

                swapData[i + 1].fromAmount = tokenReceived;
            }
        }

        // @dev check if swapDataLength is 0 and there were no swaps
        if (balanceAfter == 0) {
            revert InvalidDexData();
        }

        uint256 dstTokenReceived = balanceAfter - dstTokenProxyInitialBalance;

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
        bool isFromNative = swapData.fromToken == ZERO_ADDRESS;

        bool success;
        if (!isFromNative) {
            IERC20(swapData.fromToken).safeIncreaseAllowance(routerAddress, fromAmount);
            (success, ) = routerAddress.call(swapData.dexCallData);
        } else {
            (success, ) = routerAddress.call{value: fromAmount}(swapData.dexCallData);
        }

        if (!success) {
            revert SwapFailed();
        }
    }

    function _transferTokenToUser(address recipient, address token, uint256 amount) internal {
        if (amount == 0 || recipient == ZERO_ADDRESS) {
            revert InvalidDexData();
        }

        if (token != ZERO_ADDRESS) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) {
                revert TransferFailed();
            }
        }
    }

    /* DEPRECATED FUNCTIONS */

    using BytesLib for bytes;

    error UnwrapWNativeFailed();

    /* CONSTANT VARIABLES */
    uint256 private constant BASE_CHAIN_ID = 8453;
    uint256 private constant AVAX_CHAIN_ID = 43114;

    function entrypoint_DEPRECATED(
        IDexSwap.SwapData_DEPRECATED[] memory _swapData,
        address _recipient
    ) external payable returns (uint256) {
        if (address(this) != i_proxy) revert OnlyProxyContext(address(this));

        uint256 swapDataLength = _swapData.length;
        address destinationAddress = address(this);
        address dstToken = _swapData[swapDataLength - 1].toToken;
        uint256 dstTokenBalanceBefore = LibConcero.getBalance(dstToken, address(this));

        for (uint256 i; i < swapDataLength; ) {
            uint256 preSwapBalance = LibConcero.getBalance(_swapData[i].toToken, address(this));

            if (i == swapDataLength - 1) {
                destinationAddress = _recipient;
            }

            _performSwap(_swapData[i], destinationAddress);

            if (i < swapDataLength - 1) {
                if (_swapData[i].toToken != _swapData[i + 1].fromToken) {
                    revert InvalidTokenPath();
                }
                uint256 postSwapBalance = LibConcero.getBalance(
                    _swapData[i].toToken,
                    address(this)
                );
                uint256 remainingBalance = postSwapBalance - preSwapBalance;
                _swapData[i + 1].fromAmount = remainingBalance;
            }

            unchecked {
                ++i;
            }
        }

        //TODO: optimise this line in the future
        uint256 tokenAmountReceived = LibConcero.getBalance(dstToken, address(this)) -
            dstTokenBalanceBefore;

        emit ConceroSwap(
            _swapData[0].fromToken,
            _swapData[swapDataLength - 1].toToken,
            _swapData[0].fromAmount,
            tokenAmountReceived,
            _recipient
        );

        return tokenAmountReceived;
    }

    function _performSwap(
        IDexSwap.SwapData_DEPRECATED memory _swapData,
        address destinationAddress
    ) private {
        DexType dexType = _swapData.dexType;

        if (dexType == DexType.UniswapV3Single) {
            _swapUniV3Single(_swapData, destinationAddress);
        } else if (dexType == DexType.UniswapV3Multi) {
            _swapUniV3Multi(_swapData, destinationAddress);
        } else if (dexType == DexType.WrapNative) {
            _wrapNative(_swapData);
        } else if (dexType == DexType.UnwrapWNative) {
            _unwrapWNative(_swapData, destinationAddress);
        } else {
            revert InvalidDexData();
        }
    }

    function _wrapNative(IDexSwap.SwapData_DEPRECATED memory _swapData) private {
        address wrappedNative = _getWrappedNative();
        IWETH(wrappedNative).deposit{value: _swapData.fromAmount}();
    }

    function _unwrapWNative(
        IDexSwap.SwapData_DEPRECATED memory _swapData,
        address _recipient
    ) private {
        if (_swapData.fromToken != _getWrappedNative()) revert InvalidDexData();

        IWETH(_swapData.fromToken).withdraw(_swapData.fromAmount);

        (bool sent, ) = _recipient.call{value: _swapData.fromAmount}("");
        if (!sent) {
            revert UnwrapWNativeFailed();
        }
    }

    /**
     * @notice UniswapV3 function that executes single hop swaps
     * @param _swapData the encoded swap data
     * @dev This function can execute swap in any protocol compatible with UniV3 that implements the IV3SwapRouter
     */
    function _swapUniV3Single(
        IDexSwap.SwapData_DEPRECATED memory _swapData,
        address _recipient
    ) private {
        if (_swapData.dexData.length == 0) revert EmptyDexData();
        (address routerAddress, uint24 fee, uint160 sqrtPriceLimitX96, uint256 deadline) = abi
            .decode(_swapData.dexData, (address, uint24, uint160, uint256));

        if (!s_routerAllowed[routerAddress]) revert DexRouterNotAllowed();

        if (block.chainid == BASE_CHAIN_ID || block.chainid == AVAX_CHAIN_ID) {
            IV3SwapRouter.ExactInputSingleParams memory dex = IV3SwapRouter.ExactInputSingleParams({
                tokenIn: _swapData.fromToken,
                tokenOut: _swapData.toToken,
                fee: fee,
                recipient: _recipient,
                amountIn: _swapData.fromAmount,
                amountOutMinimum: _swapData.toAmountMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

            IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
            ISwapRouter02(routerAddress).exactInputSingle(dex);
        } else {
            ISwapRouter.ExactInputSingleParams memory dex = ISwapRouter.ExactInputSingleParams({
                tokenIn: _swapData.fromToken,
                tokenOut: _swapData.toToken,
                fee: fee,
                recipient: _recipient,
                deadline: deadline,
                amountIn: _swapData.fromAmount,
                amountOutMinimum: _swapData.toAmountMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

            IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
            ISwapRouter(routerAddress).exactInputSingle(dex);
        }
    }

    /**
     * @notice UniswapV3 function that executes multi hop swaps
     * @param _swapData the encoded swap data
     * @dev This function can execute swap in any protocol compatible
     */
    function _swapUniV3Multi(
        IDexSwap.SwapData_DEPRECATED memory _swapData,
        address _recipient
    ) private {
        if (_swapData.dexData.length == 0) revert EmptyDexData();

        (address routerAddress, bytes memory path, uint256 deadline) = abi.decode(
            _swapData.dexData,
            (address, bytes, uint256)
        );
        (address firstToken, address lastToken) = _extractTokens(path);

        if (!s_routerAllowed[routerAddress]) revert DexRouterNotAllowed();
        if (firstToken != _swapData.fromToken || lastToken != _swapData.toToken)
            revert InvalidTokenPath();

        if (block.chainid == BASE_CHAIN_ID || block.chainid == AVAX_CHAIN_ID) {
            IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
                path: path,
                recipient: _recipient,
                amountIn: _swapData.fromAmount,
                amountOutMinimum: _swapData.toAmountMin
            });

            IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
            ISwapRouter02(routerAddress).exactInput(params);
        } else {
            ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
                path: path,
                recipient: _recipient,
                deadline: deadline,
                amountIn: _swapData.fromAmount,
                amountOutMinimum: _swapData.toAmountMin
            });

            IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
            ISwapRouter(routerAddress).exactInput(params);
        }
    }

    /* HELPER FUNCTIONS */
    function _extractTokens(
        bytes memory _path
    ) private pure returns (address _firstToken, address _lastToken) {
        uint256 pathSize = _path.length;

        bytes memory tokenBytes = _path.slice(0, 20);

        assembly {
            _firstToken := mload(add(tokenBytes, 20))
        }

        bytes memory secondTokenBytes = _path.slice(pathSize - 20, 20);

        assembly {
            _lastToken := mload(add(secondTokenBytes, 20))
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IPriceRegistry, Internal} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IPriceRegistry.sol";
import {IFunctionsBillingExtension, FunctionsBilling} from "./Interfaces/IFunctionsBillingExtension.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the input amount is less than the fees
error ConceroBridge_InsufficientFees(uint256 amount, uint256 fee);
///@notice error emitted when a non orchestrator address call startBridge
error ConceroBridge_OnlyProxyContext(address caller);

contract ConceroBridge is IConceroBridge, ConceroCCIP {
    using SafeERC20 for IERC20;

    ///////////////
    ///CONSTANTS///
    ///////////////
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;
    uint64 private constant HALF_DST_GAS = 600_000;

    address internal immutable i_functionsCoordinator;
    address internal immutable i_priceRegistry;

    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////
    /// @notice event emitted when a CCIP message is sent
    event CCIPSent(
        bytes32 indexed ccipMessageId,
        address sender,
        address recipient,
        CCIPToken token,
        uint256 amount,
        uint64 dstChainSelector
    );
    /// @notice event emitted when a stuck amount is withdraw
    event Concero_StuckAmountWithdraw(address owner, address token, uint256 amount);

    constructor(
        FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers,
        address _functionsCoordinator,
        address _priceRegistry
    )
        ConceroCCIP(
            _variables,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            _dexSwap,
            _pool,
            _proxy,
            _messengers
        )
    {
        i_functionsCoordinator = _functionsCoordinator;
        i_priceRegistry = _priceRegistry;
    }

    ///////////////////////////////////////////////////////////////
    ///////////////////////////Functions///////////////////////////
    ///////////////////////////////////////////////////////////////
    /**
     * @notice Function responsible to trigger CCIP and start the bridging process
     * @param bridgeData The bytes data payload with transaction infos
     * @param dstSwapData The bytes data payload with destination swap Data
     * @dev dstSwapData can be empty if there is no swap on destination
     * @dev this function should only be able to called thought infra Proxy
     */
    function startBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable {
        if (address(this) != i_proxy) revert ConceroBridge_OnlyProxyContext(address(this));
        address fromToken = getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex);
        uint256 totalSrcFee = _convertToUSDCDecimals(
            _getSrcTotalFeeInUsdc(
                bridgeData.tokenType,
                bridgeData.dstChainSelector,
                bridgeData.amount
            )
        );

        if (bridgeData.amount < totalSrcFee) {
            revert ConceroBridge_InsufficientFees(bridgeData.amount, totalSrcFee);
        }

        uint256 amountToSend = bridgeData.amount - totalSrcFee;
        uint256 lpFee = getDstTotalFeeInUsdc(amountToSend);

        bytes32 ccipMessageId = _sendTokenPayLink(
            bridgeData.dstChainSelector,
            fromToken,
            amountToSend,
            bridgeData.receiver,
            lpFee
        );
        // TODO: for dstSwaps: add unique keccak id with all argument including dstSwapData
        //    bytes32 id = keccak256(abi.encodePacked(ccipMessageId, bridgeData, dstSwapData));
        emit CCIPSent(
            ccipMessageId,
            msg.sender,
            bridgeData.receiver,
            bridgeData.tokenType,
            amountToSend,
            bridgeData.dstChainSelector
        );
        sendUnconfirmedTX(
            ccipMessageId,
            msg.sender,
            bridgeData.receiver,
            amountToSend,
            bridgeData.dstChainSelector,
            bridgeData.tokenType,
            dstSwapData
        );
    }

    /////////////////
    ///VIEW & PURE///
    /////////////////
    /**
     * @notice Function to get the total amount of fees charged by Chainlink functions in Link
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getFunctionsFeeInLink(uint64 dstChainSelector) public view returns (uint256) {
        // uint256 srcGasPrice = s_lastGasPrices[CHAIN_SELECTOR];
        // uint256 dstGasPrice = s_lastGasPrices[dstChainSelector];

        uint256 srcGasPrice = s_lastSrcGasPrice;

        /// @dev this value is encoded differently for different chains according to the IPriceRegistry natspec
        Internal.TimestampedPackedUint224 memory timestampedPacked = IPriceRegistry(i_priceRegistry)
            .getDestinationChainGasPrice(dstChainSelector);
        /// this needs to be properly decoded
        uint256 dstGasPrice = uint256(timestampedPacked.value);

        uint256 srcClFeeInLink = uint256(
            _clfCalculateFee(srcGasPrice, CL_FUNCTIONS_SRC_CALLBACK_GAS_LIMIT)
        );
        uint256 dstClFeeInLink = uint256(
            _clfCalculateFee(dstGasPrice, CL_FUNCTIONS_DST_CALLBACK_GAS_LIMIT)
        );

        // uint256 srcClFeeInLink = clfPremiumFees[CHAIN_SELECTOR] +
        //     (srcGasPrice *
        //         (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_SRC_CALLBACK_GAS_LIMIT) *
        //         s_latestLinkNativeRate) /
        //     1e18;

        // uint256 dstClFeeInLink = clfPremiumFees[dstChainSelector] +
        //     ((dstGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_DST_CALLBACK_GAS_LIMIT)) *
        //         s_latestLinkNativeRate) /
        //     1e18;

        return srcClFeeInLink + dstClFeeInLink;
    }

    function _clfCalculateFee(
        uint256 _gasPriceWei,
        uint256 _callbackGasLimit
    ) internal view returns (uint96) {
        FunctionsBilling.Config memory config = IFunctionsBillingExtension(i_functionsCoordinator)
            .getConfig();

        uint256 executionGas = config.gasOverheadBeforeCallback +
            config.gasOverheadAfterCallback +
            _callbackGasLimit;

        uint256 gasPriceWithOverestimation = _gasPriceWei +
            ((_gasPriceWei * config.fulfillmentGasPriceOverEstimationBP) / 10_000);
        /// @NOTE: Basis Points are 1/100th of 1%, divide by 10_000 to bring back to original units

        uint96 juelsPerGas = _getJuelsPerGas(gasPriceWithOverestimation);
        uint256 estimatedGasReimbursement = juelsPerGas * executionGas;

        uint72 adminFee = IFunctionsBillingExtension(i_functionsCoordinator).getAdminFee();

        uint96 fees = uint96(config.donFee) + uint96(adminFee);

        return SafeCast.toUint96(estimatedGasReimbursement + fees);
    }

    function _getJuelsPerGas(uint256 _gasPriceWei) private view returns (uint96) {
        // (1e18 juels/link) * (wei/gas) / (wei/link) = juels per gas
        // There are only 1e9*1e18 = 1e27 juels in existence, should not exceed uint96 (2^96 ~ 7e28)
        return
            SafeCast.toUint96(
                (1e18 * _gasPriceWei) /
                    // IFunctionsBillingExtension(i_functionsCoordinator).getWeiPerUnitLink()
                    s_latestLinkNativeRate
            );
    }

    /**
     * @notice Function to get the total amount of fees charged by Chainlink functions in USDC
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getFunctionsFeeInUsdc(uint64 dstChainSelector) public view returns (uint256) {
        //    uint256 functionsFeeInLink = getFunctionsFeeInLink(dstChainSelector);
        //    return (functionsFeeInLink * s_latestLinkUsdcRate) / STANDARD_TOKEN_DECIMALS;

        return clfPremiumFees[dstChainSelector] + clfPremiumFees[CHAIN_SELECTOR];
    }

    /**
     * @notice Function to get the total amount of CCIP fees in Link
     * @param tokenType the position of the CCIPToken enum
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getCCIPFeeInLink(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 _amount
    ) public view returns (uint256) {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            getUSDCAddressByChainIndex(tokenType, i_chainIndex),
            _amount,
            address(this),
            (_amount / 1000),
            dstChainSelector
        );
        return i_ccipRouter.getFee(dstChainSelector, evm2AnyMessage);
    }

    /**
     * @notice Function to get the total amount of CCIP fees in USDC
     * @param tokenType the position of the CCIPToken enum
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getCCIPFeeInUsdc(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 _amount
    ) public view returns (uint256) {
        uint256 ccpFeeInLink = getCCIPFeeInLink(tokenType, dstChainSelector, _amount);
        return (ccpFeeInLink * uint256(s_latestLinkUsdcRate)) / STANDARD_TOKEN_DECIMALS;
    }

    /**
     * @notice Function to get the total amount of fees on the source
     * @param tokenType the position of the CCIPToken enum
     * @param dstChainSelector the destination blockchain chain selector
     * @param amount the amount of value the fees will calculated over.
     */
    function _getSrcTotalFeeInUsdc(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) internal view returns (uint256) {
        // @notice cl functions fee
        uint256 functionsFeeInUsdc = getFunctionsFeeInUsdc(dstChainSelector);

        // @notice cl ccip fee
        uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(tokenType, dstChainSelector, amount);

        // @notice concero fee
        uint256 conceroFee = amount / CONCERO_FEE_FACTOR;

        // @notice gas fee
        uint256 messengerDstGasInNative = HALF_DST_GAS * s_lastGasPrices[dstChainSelector];
        uint256 messengerSrcGasInNative = HALF_DST_GAS * s_lastGasPrices[CHAIN_SELECTOR];
        uint256 messengerGasFeeInUsdc = ((messengerDstGasInNative + messengerSrcGasInNative) *
            s_latestNativeUsdcRate) / STANDARD_TOKEN_DECIMALS;

        return (functionsFeeInUsdc + ccipFeeInUsdc + conceroFee + messengerGasFeeInUsdc);
    }

    function getSrcTotalFeeInUSDC(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256) {
        return _getSrcTotalFeeInUsdc(tokenType, dstChainSelector, amount);
    }
}

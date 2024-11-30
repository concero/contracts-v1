// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {InfraCCIP} from "./InfraCCIP.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";

/* ERRORS */
///@notice error emitted when the input amount is less than the fees
error InsufficientFees(uint256 amount, uint256 fee);
///@notice error emitted when a non orchestrator address call startBridge
error OnlyProxyContext(address caller);

contract ConceroBridge is IConceroBridge, InfraCCIP {
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;
    uint64 private constant HALF_DST_GAS = 200_000;
    // TODO: rollback it in prod
    //    uint256 internal constant BATCHED_TX_THRESHOLD = 5_000_000_000;
    uint256 internal constant BATCHED_TX_THRESHOLD = 3 * 1e6;
    uint8 internal constant MAX_PENDING_SETTLEMENT_TXS_BY_LANE = 200;
    uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 220_500;

    constructor(
        FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    )
        InfraCCIP(
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
    {}

    /* FUNCTIONS */
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
    ) external payable {
        if (address(this) != i_proxy) revert OnlyProxyContext(address(this));
        uint64 dstChainSelector = bridgeData.dstChainSelector;
        uint256 amount = bridgeData.amount;
        address fromToken = _getUSDCAddressByChainIndex(CCIPToken.usdc, i_chainIndex);
        uint256 totalSrcFee = _convertToUSDCDecimals(
            _getSrcTotalFeeInUsdc(dstChainSelector, amount)
        );

        if (amount <= totalSrcFee) {
            revert InsufficientFees(amount, totalSrcFee);
        }
        uint256 amountToSendAfterFees = amount - totalSrcFee;
        uint256 batchedTxAmount = s_pendingSettlementTxAmountByDstChain[dstChainSelector];

        bytes32 conceroMessageId = keccak256(
            abi.encode(
                dstChainSelector,
                i_chainSelector,
                msg.sender,
                bridgeData.receiver,
                amountToSendAfterFees,
                batchedTxAmount,
                block.number
            )
        );

        bytes32 txDataHash = keccak256(
            abi.encode(
                conceroMessageId,
                amountToSendAfterFees,
                dstChainSelector,
                bridgeData.receiver,
                keccak256(compressedDstSwapData)
            )
        );

        _addPendingSettlementTx(
            conceroMessageId,
            amountToSendAfterFees,
            bridgeData.receiver,
            dstChainSelector
        );

        _sendUnconfirmedTX(conceroMessageId, dstChainSelector, txDataHash);

        if (
            batchedTxAmount >= BATCHED_TX_THRESHOLD ||
            s_pendingSettlementIdsByDstChain[dstChainSelector].length >=
            MAX_PENDING_SETTLEMENT_TXS_BY_LANE
        ) {
            _sendBatchViaSettlement(fromToken, batchedTxAmount, dstChainSelector);
        }

        emit ConceroBridgeSent(
            conceroMessageId,
            amountToSendAfterFees,
            dstChainSelector,
            bridgeData.receiver,
            compressedDstSwapData
        );
    }

    function _addPendingSettlementTx(
        bytes32 conceroMessageId,
        uint256 amountToSendAfterFees,
        address receiver,
        uint64 dstChainSelector
    ) internal {
        SettlementTx memory bridgeTx = SettlementTx(amountToSendAfterFees, receiver);

        s_pendingSettlementIdsByDstChain[dstChainSelector].push(conceroMessageId);
        s_pendingSettlementTxsById[conceroMessageId] = bridgeTx;
        s_pendingSettlementTxAmountByDstChain[dstChainSelector] += amountToSendAfterFees;
    }

    /* VIEW & PURE FUNCTIONS */
    /**
     * @notice Function to get the total amount of fees charged by Chainlink functions in Link
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getFunctionsFeeInLink(uint64 dstChainSelector) public view returns (uint256) {
        uint256 srcGasPrice = s_lastGasPrices[i_chainSelector];
        uint256 dstGasPrice = s_lastGasPrices[dstChainSelector];
        uint256 srcClFeeInLink = clfPremiumFees[i_chainSelector] +
            (srcGasPrice *
                (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_SRC_CALLBACK_GAS_LIMIT) *
                s_latestLinkNativeRate) /
            1e18;

        uint256 dstClFeeInLink = clfPremiumFees[dstChainSelector] +
            ((dstGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_DST_CALLBACK_GAS_LIMIT)) *
                s_latestLinkNativeRate) /
            1e18;

        return srcClFeeInLink + dstClFeeInLink;
    }

    /**
     * @notice Function to get the total amount of fees charged by Chainlink functions in USDC
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getFunctionsFeeInUsdc(uint64 dstChainSelector) public view returns (uint256) {
        //    uint256 functionsFeeInLink = getFunctionsFeeInLink(dstChainSelector);
        //    return (functionsFeeInLink * s_latestLinkUsdcRate) / STANDARD_TOKEN_DECIMALS;
        return clfPremiumFees[dstChainSelector] + clfPremiumFees[i_chainSelector];
    }

    /**
     * @notice Function to get the total amount of CCIP fees in Link
     * @param _dstChainSelector the destination blockchain chain selector
     */
    function getCCIPFeeInLink(uint64 _dstChainSelector) public view returns (uint256) {
        return s_lastCCIPFeeInLink[_dstChainSelector];
    }

    /**
     * @notice Function to get the total amount of CCIP fees in USDC
     * @param _dstChainSelector the destination blockchain chain selector
     */
    function getCCIPFeeInUsdc(uint64 _dstChainSelector) public view returns (uint256) {
        uint256 ccipFeeInLink = s_lastCCIPFeeInLink[_dstChainSelector];
        return (ccipFeeInLink * uint256(s_latestLinkUsdcRate)) / STANDARD_TOKEN_DECIMALS;
    }

    function getSrcTotalFeeInUSDC(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256) {
        return _getSrcTotalFeeInUsdc(dstChainSelector, amount);
    }

    /* INTERNAL FUNCTIONS */

    function _sendBatchViaSettlement(
        address fromToken,
        uint256 batchedTxAmount,
        uint64 dstChainSelector
    ) internal {
        bytes32[] memory pendingCCIPTransactionsByDstChain = s_pendingSettlementIdsByDstChain[
            dstChainSelector
        ];

        CcipSettlementTx[] memory ccipSettlementTxs = new CcipSettlementTx[](
            pendingCCIPTransactionsByDstChain.length
        );

        for (uint256 i; i < pendingCCIPTransactionsByDstChain.length; ++i) {
            bytes32 txId = pendingCCIPTransactionsByDstChain[i];
            SettlementTx memory pendingSettlementTx = s_pendingSettlementTxsById[txId];
            ccipSettlementTxs[i] = CcipSettlementTx(
                txId,
                pendingSettlementTx.amount,
                pendingSettlementTx.recipient
            );
        }

        delete s_pendingSettlementIdsByDstChain[dstChainSelector];
        s_pendingSettlementTxAmountByDstChain[dstChainSelector] = 0;

        bytes32 ccipMessageId = _sendTokenPayLink(
            dstChainSelector,
            fromToken,
            batchedTxAmount,
            ccipSettlementTxs
        );
        emit ConceroSettlementSent(ccipMessageId, batchedTxAmount);
    }

    /**
     * @notice Function to get the total amount of fees on the source
     * @param dstChainSelector the destination blockchain chain selector
     * @param amount the amount of value the fees will calculated over.
     */
    function _getSrcTotalFeeInUsdc(
        uint64 dstChainSelector,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 functionsFeeInUsdc = getFunctionsFeeInUsdc(dstChainSelector);
        uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(dstChainSelector);
        uint256 proportionalCCIPFeeInUSDC = _calculateProportionalCCIPFee(ccipFeeInUsdc, amount);

        uint256 conceroFee = amount / CONCERO_FEE_FACTOR;

        uint256 messengerDstGasInNative = HALF_DST_GAS * s_lastGasPrices[dstChainSelector];
        uint256 messengerSrcGasInNative = HALF_DST_GAS * s_lastGasPrices[i_chainSelector];
        uint256 messengerGasFeeInUsdc = ((messengerDstGasInNative + messengerSrcGasInNative) *
            s_latestNativeUsdcRate) / STANDARD_TOKEN_DECIMALS;

        return (functionsFeeInUsdc +
            proportionalCCIPFeeInUSDC +
            conceroFee +
            messengerGasFeeInUsdc);
    }

    /**
     * @notice Function to calculate the proportional CCIP fee based on the amount
     * @param ccipFeeInUsdc the total CCIP fee for a full batch (5000 USDC)
     * @param amount the amount of USDC being transferred
     */
    function _calculateProportionalCCIPFee(
        uint256 ccipFeeInUsdc,
        uint256 amount
    ) internal pure returns (uint256) {
        if (amount >= BATCHED_TX_THRESHOLD) return ccipFeeInUsdc;
        return (ccipFeeInUsdc * amount) / BATCHED_TX_THRESHOLD;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {CHAIN_SELECTOR_ARBITRUM, CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON, CHAIN_SELECTOR_AVALANCHE, CHAIN_SELECTOR_ETHEREUM} from "./Constants.sol";
import {InfraCommon} from "./InfraCommon.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IInfraCLF} from "./Interfaces/IInfraCLF.sol";
import {IInfraOrchestrator, IOrchestratorViewDelegate} from "./Interfaces/IInfraOrchestrator.sol";
import {InfraStorageSetters} from "./Libraries/InfraStorageSetters.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* ERRORS */
///@notice error emitted when the balance input is smaller than the specified amount param
error InvalidAmount();
///@notice error emitted when a address non-router calls the `handleOracleFulfillment` function
error OnlyCLFRouter();
///@notice error emitted when some params of Bridge Data are empty
error InvalidBridgeData();
///@notice error emitted when an empty swapData is the input
error InvalidSwapData();
///@notice error emitted when the token to bridge is not USDC
error UnsupportedBridgeToken();
error InvalidIntegratorFeeBps();
error InvalidRecipient();
error TransferFailed();
error TxAlreadyConfirmed();
error OnlyPool();

contract InfraOrchestrator is
    IFunctionsClient,
    IInfraOrchestrator,
    InfraCommon,
    InfraStorageSetters
{
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint8 internal constant SUPPORTED_CHAINS_COUNT = 6;
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1000;
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;
    uint16 internal constant BPS_DIVISOR = 10000;

    /* IMMUTABLE VARIABLES */
    address internal immutable i_functionsRouter;
    address internal immutable i_dexSwap;
    address internal immutable i_conceroBridge;
    address internal immutable i_pool;
    address internal immutable i_proxy; //TODO: unused. Remove this when removing onlyProxyContext
    Chain internal immutable i_chainIndex;

    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _conceroBridge,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    ) InfraCommon(_messengers) InfraStorageSetters(msg.sender) {
        i_functionsRouter = _functionsRouter;
        i_dexSwap = _dexSwap;
        i_conceroBridge = _conceroBridge;
        i_pool = _pool;
        i_proxy = _proxy;
        i_chainIndex = Chain(_chainIndex);
    }

    receive() external payable {}

    /* MODIFIERS */
    modifier validateBridgeData(BridgeData memory bridgeData) {
        if (bridgeData.amount == 0 || bridgeData.receiver == address(0)) {
            revert InvalidBridgeData();
        }
        _;
    }

    modifier validateSrcSwapData(IDexSwap.SwapData[] memory swapData) {
        if (swapData.length == 0 || swapData.length > 5 || swapData[0].fromAmount == 0) {
            revert InvalidSwapData();
        }
        _;
    }

    /* VIEW FUNCTIONS */
    function getSrcTotalFeeInUSDC(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256) {
        return
            IOrchestratorViewDelegate(address(this)).getSrcTotalFeeInUSDCViaDelegateCall(
                tokenType,
                dstChainSelector,
                amount
            );
    }

    function getSrcTotalFeeInUSDCViaDelegateCall(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external returns (uint256) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IConceroBridge.getSrcTotalFeeInUSDC.selector,
            tokenType,
            dstChainSelector,
            amount
        );

        bytes memory delegateCallRes = LibConcero.safeDelegateCall(
            i_conceroBridge,
            delegateCallArgs
        );

        return _convertToUSDCDecimals(abi.decode(delegateCallRes, (uint256)));
    }

    /**
     * @notice Performs a bridge coupled with the source chain swap and an optional destination chain swap.
     * @param bridgeData bridge payload of type BridgeData
     * @param srcSwapData swap payload for the source chain of type IDexSwap.SwapData[]
     * @param compressedDstSwapData swap payload for the destination chain of type IDexSwap.SwapData[]. May be empty
     * @param integration the integrator fee data
     */
    function swapAndBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] calldata srcSwapData,
        bytes memory compressedDstSwapData,
        Integration memory integration
    )
        external
        payable
        validateSrcSwapData(srcSwapData)
        validateBridgeData(bridgeData)
        nonReentrant
    {
        address usdc = _getUSDCAddressByChainIndex(CCIPToken.usdc, i_chainIndex);

        if (srcSwapData[srcSwapData.length - 1].toToken != usdc) {
            revert InvalidSwapData();
        }

        _obtainSwapDataFromToken(srcSwapData);

        uint256 amountReceivedFromSwap = _swap(srcSwapData, address(this));
        bridgeData.amount =
            amountReceivedFromSwap -
            _collectIntegratorFee(usdc, amountReceivedFromSwap, integration);

        _bridge(bridgeData, compressedDstSwapData);
    }

    /**
     * @notice Performs a swap on a single chain.
     * @param swapData the swap payload of type IDexSwap.SwapData[]
     * @param receiver the recipient of the swap
     * @param integration the integrator fee data
     */
    function swap(
        IDexSwap.SwapData[] memory swapData,
        address receiver,
        Integration memory integration
    ) external payable validateSrcSwapData(swapData) nonReentrant {
        _obtainSwapDataFromToken(swapData);
        swapData = _collectSwapFee(swapData, integration);
        _swap(swapData, receiver);
    }

    /**
     * @notice Performs a bridge from the source chain to the destination chain.
     * @param bridgeData bridge payload of type BridgeData
     * @param compressedDstSwapData destination swap payload. May be empty
     */
    function bridge(
        BridgeData memory bridgeData,
        bytes memory compressedDstSwapData,
        Integration memory integration
    ) external payable validateBridgeData(bridgeData) nonReentrant {
        address fromToken = _getUSDCAddressByChainIndex(CCIPToken.usdc, i_chainIndex);
        LibConcero.transferFromERC20(fromToken, msg.sender, address(this), bridgeData.amount);
        bridgeData.amount -= _collectIntegratorFee(fromToken, bridgeData.amount, integration);

        _bridge(bridgeData, compressedDstSwapData);
    }

    /**
     * @notice Wrapper function to delegate call to ConceroBridge.addUnconfirmedTX
     * @param conceroMessageId the Concerro message ID
     * @param srcChainSelector the source chain selector
     * @param txDataHash the transaction data hash
     */
    function addUnconfirmedTX(
        bytes32 conceroMessageId,
        uint64 srcChainSelector,
        bytes32 txDataHash
    ) external onlyMessenger {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IInfraCLF.addUnconfirmedTX.selector,
            conceroMessageId,
            srcChainSelector,
            txDataHash
        );

        LibConcero.safeDelegateCall(i_conceroBridge, delegateCallArgs);
    }

    /**
     * @notice Helper function to delegate call to ConceroBridge contract
     * @param requestId the CLF request ID from callback
     * @param response the response
     * @param err the error
     * @dev response and error will never be populated at the same time.
     */
    function handleOracleFulfillment(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external {
        if (msg.sender != address(i_functionsRouter)) {
            revert OnlyCLFRouter();
        }

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IInfraCLF.fulfillRequestWrapper.selector,
            requestId,
            response,
            err
        );

        LibConcero.safeDelegateCall(i_conceroBridge, delegateCallArgs);
    }

    /**
     * @notice Function to withdraw integrator fees
     * @param tokens array of token addresses to withdraw
     */
    function withdrawIntegratorFees(address[] memory tokens) external nonReentrant {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = s_integratorFeesAmountByToken[msg.sender][token];

            if (amount > 0) {
                s_integratorFeesAmountByToken[msg.sender][token] = 0;
                s_totalIntegratorFeesAmountByToken[token] -= amount;

                if (token == address(0)) {
                    (bool success, ) = msg.sender.call{value: amount}("");
                    if (!success) revert TransferFailed();
                } else {
                    IERC20(token).safeTransfer(msg.sender, amount);
                }

                emit IntegratorFeesWithdrawn(msg.sender, token, amount);
            }
        }
    }

    /**
     * @notice Function to allow Concero Team to withdraw fees
     * @param recipient the recipient address
     * @param tokens array of token addresses to withdraw
     */
    function withdrawConceroFees(
        address recipient,
        address[] calldata tokens
    ) external payable onlyOwner nonReentrant {
        if (recipient == address(0)) {
            revert InvalidRecipient();
        }
        address usdc = _getUSDCAddressByChainIndex(CCIPToken.usdc, i_chainIndex);

        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 balance = LibConcero.getBalance(token, address(this));
            uint256 integratorFees = s_totalIntegratorFeesAmountByToken[token];
            uint256 availableBalance = balance - integratorFees;

            if (token == usdc) {
                uint256 batchedReserves;
                //TODO: move to getSupportedChainSelectors, which should use immutable variables passed to infraCommon
                uint64[SUPPORTED_CHAINS_COUNT] memory chainSelectors = [
                    CHAIN_SELECTOR_ARBITRUM,
                    CHAIN_SELECTOR_BASE,
                    CHAIN_SELECTOR_POLYGON,
                    CHAIN_SELECTOR_AVALANCHE,
                    CHAIN_SELECTOR_ETHEREUM,
                    CHAIN_SELECTOR_OPTIMISM
                ];
                for (uint256 j = 0; j < SUPPORTED_CHAINS_COUNT; ++j) {
                    batchedReserves += s_pendingSettlementTxAmountByDstChain[chainSelectors[j]];
                }
                availableBalance -= batchedReserves;
                if (availableBalance <= 0) {
                    revert InvalidAmount();
                }
                LibConcero.transferERC20(usdc, availableBalance, recipient);
            } else {
                if (availableBalance <= 0) {
                    revert InvalidAmount();
                }

                if (token == address(0)) {
                    (bool success, ) = payable(recipient).call{value: availableBalance}("");
                    if (!success) {
                        revert TransferFailed();
                    }
                } else {
                    LibConcero.transferERC20(token, availableBalance, recipient);
                }
            }
        }
    }

    function isTxConfirmed(bytes32 _conceroMessageId) external view returns (bool) {
        bytes32 txDataHash = s_transactions[_conceroMessageId].txDataHash;
        if (txDataHash == bytes32(0)) {
            return false;
        }
        bool isConfirmed = s_transactions[_conceroMessageId].isConfirmed;
        if (!isConfirmed) {
            return false;
        }
        return true;
    }

    function confirmTx(bytes32 _conceroMessageId) external {
        if (msg.sender != i_pool) {
            revert OnlyPool();
        }

        if (s_transactions[_conceroMessageId].isConfirmed) {
            revert TxAlreadyConfirmed();
        }
        s_transactions[_conceroMessageId].isConfirmed = true;
    }

    /* INTERNAL FUNCTIONS */
    function _obtainSwapDataFromToken(IDexSwap.SwapData[] memory swapData) internal {
        address initialToken = swapData[0].fromToken;
        uint256 initialAmount = swapData[0].fromAmount;

        if (initialToken != address(0)) {
            LibConcero.transferFromERC20(initialToken, msg.sender, address(this), initialAmount);
        } else {
            if (initialAmount != msg.value) revert InvalidAmount();
        }
    }

    /**
     * @notice Internal function to perform swaps. Delegate calls DexSwap.entrypoint
     * @param swapData the payload to be passed to swap functions
     * @param receiver the address of the receiver of the swap
     */
    function _swap(
        IDexSwap.SwapData[] memory swapData,
        address receiver
    ) internal returns (uint256) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IDexSwap.entrypoint.selector,
            swapData,
            receiver
        );
        bytes memory delegateCallRes = LibConcero.safeDelegateCall(i_dexSwap, delegateCallArgs);
        return abi.decode(delegateCallRes, (uint256));
    }

    function _bridge(BridgeData memory bridgeData, bytes memory _compressedSwapData) internal {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IConceroBridge.bridge.selector,
            bridgeData,
            _compressedSwapData
        );
        LibConcero.safeDelegateCall(i_conceroBridge, delegateCallArgs);
    }

    // function _getUSDCAddressByChainSelector(
    //     uint64 _chainSelector
    // ) internal pure returns (address _token) {
    //     if (_chainSelector == CHAIN_SELECTOR_ARBITRUM) {
    //         _token = USDC_ARBITRUM;
    //     } else if (_chainSelector == CHAIN_SELECTOR_BASE) {
    //         _token = USDC_BASE;
    //     } else if (_chainSelector == CHAIN_SELECTOR_POLYGON) {
    //         _token = USDC_POLYGON;
    //     } else if (_chainSelector == CHAIN_SELECTOR_AVALANCHE) {
    //         _token = USDC_AVALANCHE;
    //     } else {
    //         revert UnsupportedBridgeToken();
    //     }
    // }

    function _collectSwapFee(
        IDexSwap.SwapData[] memory swapData,
        Integration memory integration
    ) internal returns (IDexSwap.SwapData[] memory) {
        swapData[0].fromAmount -= (swapData[0].fromAmount / CONCERO_FEE_FACTOR);

        swapData[0].fromAmount -= _collectIntegratorFee(
            swapData[0].fromToken,
            swapData[0].fromAmount,
            integration
        );

        return swapData;
    }

    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration memory integration
    ) internal returns (uint256) {
        if (integration.integrator == address(0)) return 0;
        if (integration.feeBps > MAX_INTEGRATOR_FEE_BPS) revert InvalidIntegratorFeeBps();

        uint256 integratorFeeAmount = (amount * integration.feeBps) / BPS_DIVISOR;
        if (integratorFeeAmount == 0) return 0;

        s_integratorFeesAmountByToken[integration.integrator][token] += integratorFeeAmount;
        s_totalIntegratorFeesAmountByToken[token] += integratorFeeAmount;

        emit IntegratorFeesCollected(integration.integrator, token, integratorFeeAmount);
        return integratorFeeAmount;
    }
}

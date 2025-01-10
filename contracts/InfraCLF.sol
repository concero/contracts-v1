// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity ^0.8.20;

import {InfraCommon} from "./InfraCommon.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IInfraCLF} from "./Interfaces/IInfraCLF.sol";
import {IPool} from "./Interfaces/IPool.sol";
import {InfraStorage} from "./Libraries/InfraStorage.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {LibZip} from "solady/src/utils/LibZip.sol";

/* ERRORS */
///@notice error emitted when a TX was already added
error TxAlreadyExists(bytes32 txHash);
///@notice error emitted when a unexpected ID is added
error UnexpectedCLFRequestId(bytes32 requestId);
///@notice error emitted when a transaction does not exist
error TxDoesntExist();
error TxDataHashSumMismatch();
///@notice error emitted when a transaction was already confirmed
error TxAlreadyConfirmed();
///@notice error emitted when function receive a call from a not allowed address
error DstContractAddressNotSet();
///@notice error emitted when an arbitrary address calls fulfillRequestWrapper
error OnlyProxyContext(address caller);
error InvalidSwapData();

contract InfraCLF is IInfraCLF, FunctionsClient, InfraCommon, InfraStorage {
    /* TYPE DECLARATIONS */
    using SafeERC20 for IERC20;
    using FunctionsRequest for FunctionsRequest.Request;

    /* CONSTANT VARIABLES */
    uint256 internal constant PRECISION_HANDLER = 10_000_000_000;
    uint256 internal constant LP_FEE_FACTOR = 1000;
    uint32 public constant CL_FUNCTIONS_SRC_CALLBACK_GAS_LIMIT = 150_000;
    uint32 public constant CL_FUNCTIONS_DST_CALLBACK_GAS_LIMIT = 2_000_000;
    string private constant CL_JS_CODE =
        "try{const m='https://raw.githubusercontent.com/';const u=m+'ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';const [t,p]=await Promise.all([ fetch(u),fetch(m+'concero/contracts-v1/'+'release'+`/tasks/CLFScripts/dist/infra/${BigInt(bytesArgs[2])===1n ? 'DST':'SRC'}.min.js`,),]);const [e,c]=await Promise.all([t.text(),p.text()]);const g=async s=>{return('0x'+Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(v=>('0'+v.toString(16)).slice(-2).toLowerCase()).join(''));};const r=await g(c);const x=await g(e);const b=bytesArgs[0].toLowerCase();const o=bytesArgs[1].toLowerCase();if(r===b && x===o){const ethers=new Function(e+';return ethers;')();return await eval(c);}throw new Error(`${r}!=${b}||${x}!=${o}`);}catch(e){throw new Error(e.message.slice(0,255));}";

    /* IMMUTABLE VARIABLES */
    ///@notice Chainlink Function Don ID
    bytes32 private immutable i_donId;
    ///@notice Chainlink Functions Protocol Subscription ID
    uint64 private immutable i_subscriptionId;
    //@notice CCIP chainSelector
    uint64 internal immutable i_chainSelector;
    ///@notice variable to store the DexSwap address
    address internal immutable i_dexSwap;
    ///@notice variable to store the ConceroPool address
    address internal immutable i_poolProxy;
    ///@notice Immutable variable to hold proxy address
    address internal immutable i_proxy;
    ///@notice ID of the deployed chain on getChain() function
    Chain internal immutable i_chainIndex;

    /* EVENTS */
    ///@notice emitted when a Unconfirmed TX is added by a cross-chain TX
    event UnconfirmedTXAdded(bytes32 indexed conceroMessageId);
    event TXReleased(
        bytes32 indexed conceroMessageId,
        address indexed recipient,
        address token,
        uint256 amount
    );

    ///@notice emitted when a Function Request returns an error
    event CLFRequestError(bytes32 indexed ccipMessageId, bytes32 requestId, uint8 requestType);
    ///@notice emitted when the concero pool address is updated
    event ConceroPoolAddressUpdated(address previousAddress, address pool);
    ///@notice emitted when dexSwap delegateCall fails in handleDstFunctionsResponse
    event DstSwapFailed(bytes32 conceroMessageId);

    constructor(
        FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    ) FunctionsClient(_variables.functionsRouter) InfraCommon(_messengers) {
        i_donId = _variables.donId;
        i_subscriptionId = _variables.subscriptionId;
        i_chainSelector = _chainSelector;
        i_chainIndex = Chain(_chainIndex);
        i_dexSwap = _dexSwap;
        i_poolProxy = _pool;
        i_proxy = _proxy;
    }

    /* FUNCTIONS */

    /**
     * @notice Receives an unconfirmed TX from the source chain and validates it through Chainlink Functions
     * @param conceroMessageId the concero message ID
     * @param srcChainSelector the source chain selector
     * @param txDataHash the hash of the data to be sent to the destination chain
     */
    function addUnconfirmedTX(
        bytes32 conceroMessageId,
        uint64 srcChainSelector,
        bytes32 txDataHash
    ) external onlyMessenger {
        if (s_transactions[conceroMessageId].txDataHash != bytes32(0)) {
            revert TxAlreadyExists(conceroMessageId);
        } else {
            s_transactions[conceroMessageId].txDataHash = txDataHash;
        }

        address srcContract = s_conceroContracts[srcChainSelector];
        if (srcContract == address(0)) {
            revert DstContractAddressNotSet();
        }

        bytes[] memory args = new bytes[](7);
        args[0] = abi.encodePacked(s_dstJsHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(RequestType.checkTxSrc);
        args[3] = abi.encodePacked(srcContract);
        args[4] = abi.encodePacked(srcChainSelector);
        args[5] = abi.encodePacked(conceroMessageId);
        args[6] = abi.encodePacked(txDataHash);

        bytes32 reqId = _initializeAndSendClfRequest(
            args,
            CL_JS_CODE,
            CL_FUNCTIONS_DST_CALLBACK_GAS_LIMIT
        );

        s_requests[reqId].requestType = RequestType.checkTxSrc;
        s_requests[reqId].isPending = true;
        s_requests[reqId].conceroMessageId = conceroMessageId;

        emit UnconfirmedTXAdded(conceroMessageId);
    }

    /**
     * @notice Function to send a Request to Chainlink Functions
     * @param args the arguments for the request as bytes array
     * @param jsCode the JScode that will be executed.
     */
    function _initializeAndSendClfRequest(
        bytes[] memory args,
        string memory jsCode,
        uint32 gasLimit
    ) internal returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(jsCode);
        req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
        req.setBytesArgs(args);
        return _sendRequest(req.encodeCBOR(), i_subscriptionId, gasLimit, i_donId);
    }

    /**
     * @notice Function to receive delegatecall from Orchestrator Proxy
     * @param requestId the ID of CLF request
     * @param response the response of CLF request
     * @param err the error of CLF request
     * @dev We will always receive response or err populated. Never both.
     */
    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external {
        if (address(this) != i_proxy) {
            revert OnlyProxyContext(address(this));
        }

        fulfillRequest(requestId, response, err);
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice CLF internal function to fulfill requests
     * @param requestId the initiate request ID
     * @param response the response
     * @param err the error
     * @dev response and error will never be populated at the same time.
     */
    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        Request storage request = s_requests[requestId];

        if (!request.isPending) {
            revert UnexpectedCLFRequestId(requestId);
        } else {
            request.isPending = false;
        }

        if (err.length > 0) {
            emit CLFRequestError(request.conceroMessageId, requestId, uint8(request.requestType));
            return;
        }

        if (request.requestType == RequestType.checkTxSrc) {
            _handleDstFunctionsResponse(requestId, response);
        } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
            _handleSrcFunctionsResponse(response);
        }
    }

    /**
     * @notice Sends an unconfirmed TX to the destination chain
     * @param conceroMessageId the concero message ID
     * @param dstChainSelector the destination chain selector
     * @param txDataHash the hash of the data to be sent to the destination chain
     */
    function _sendUnconfirmedTX(
        bytes32 conceroMessageId,
        uint64 dstChainSelector,
        bytes32 txDataHash
    ) internal {
        address destinationContract = s_conceroContracts[dstChainSelector];
        if (destinationContract == address(0)) {
            revert DstContractAddressNotSet();
        }

        bytes[] memory args = new bytes[](8);
        args[0] = abi.encodePacked(s_srcJsHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(RequestType.addUnconfirmedTxDst);
        args[3] = abi.encodePacked(destinationContract);
        args[4] = abi.encodePacked(conceroMessageId);
        args[5] = abi.encodePacked(i_chainSelector);
        args[6] = abi.encodePacked(dstChainSelector);
        args[7] = abi.encodePacked(txDataHash);

        bytes32 reqId = _initializeAndSendClfRequest(
            args,
            CL_JS_CODE,
            CL_FUNCTIONS_SRC_CALLBACK_GAS_LIMIT
        );

        s_requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
        s_requests[reqId].isPending = true;
        s_requests[reqId].conceroMessageId = conceroMessageId;
    }

    /**
     * @notice Internal CLF function to finalize bridge process on Destination
     * @param response the response from the CLF
     */
    function _handleDstFunctionsResponse(bytes32 requestId, bytes memory response) internal {
        bytes32 conceroMessageId = s_requests[requestId].conceroMessageId;
        bytes32 txDataHash = s_transactions[conceroMessageId].txDataHash;

        if (txDataHash == bytes32(0)) {
            revert TxDoesntExist();
        }

        if (s_transactions[conceroMessageId].isConfirmed) {
            revert TxAlreadyConfirmed();
        } else {
            s_transactions[conceroMessageId].isConfirmed = true;
        }

        (
            address receiver,
            uint256 amount,
            bytes memory compressedDstSwapData
        ) = _decodeDstClfResponse(response);

        {
            bytes32 recomputedTxDataHash = keccak256(
                abi.encode(
                    conceroMessageId,
                    amount,
                    i_chainSelector,
                    receiver,
                    keccak256(compressedDstSwapData)
                )
            );

            if (recomputedTxDataHash != txDataHash) {
                revert TxDataHashSumMismatch();
            }
        }

        address bridgeableTokenDst = _getUSDCAddressByChainIndex(CCIPToken.usdc, i_chainIndex);
        uint256 amountUsdcAfterFees = amount - getDstTotalFeeInUsdc(amount);
        IDexSwap.SwapData[] memory swapData = _decompressSwapData(compressedDstSwapData);

        if (swapData.length == 0) {
            IPool(i_poolProxy).takeLoan(bridgeableTokenDst, amountUsdcAfterFees, receiver);
        } else {
            _performDstSwap(
                swapData,
                amountUsdcAfterFees,
                conceroMessageId,
                receiver,
                bridgeableTokenDst
            );
        }

        emit TXReleased(conceroMessageId, receiver, bridgeableTokenDst, amountUsdcAfterFees);
    }

    function _performDstSwap(
        IDexSwap.SwapData[] memory swapData,
        uint256 amountUsdcAfterFees,
        bytes32 conceroMessageId,
        address receiver,
        address bridgeableTokenDst
    ) internal {
        //todo: remove with new DexSwap contract
        //TODO: when validation fails, take loan and fulfil bridge TX
        if (swapData.length > 5) {
            revert InvalidSwapData();
        }

        swapData[0].fromAmount = amountUsdcAfterFees;
        swapData[0].fromToken = bridgeableTokenDst;

        IPool(i_poolProxy).takeLoan(bridgeableTokenDst, amountUsdcAfterFees, address(this));

        bytes memory swapDataArgs = abi.encodeWithSelector(
            IDexSwap.entrypoint.selector,
            swapData,
            receiver
        );

        (bool success, ) = i_dexSwap.delegatecall(swapDataArgs);
        if (!success) {
            LibConcero.transferERC20(bridgeableTokenDst, amountUsdcAfterFees, receiver);
            emit DstSwapFailed(conceroMessageId);
        }
    }

    function _decompressSwapData(
        bytes memory compressedDstSwapData
    ) internal pure returns (IDexSwap.SwapData[] memory swapData) {
        bytes memory decompressedDstSwapData = LibZip.cdDecompress(compressedDstSwapData);

        if (decompressedDstSwapData.length == 0) {
            return new IDexSwap.SwapData[](0);
        } else {
            return abi.decode(decompressedDstSwapData, (IDexSwap.SwapData[]));
        }
    }

    function _decodeDstClfResponse(
        bytes memory response
    ) internal pure returns (address receiver, uint256 amount, bytes memory compressedDstSwapData) {
        assembly {
            receiver := mload(add(response, 32))
            amount := mload(add(response, 64))
        }

        if (response.length > 64) {
            uint256 compressedDstSwapDataLength = response.length - 64;
            compressedDstSwapData = new bytes(compressedDstSwapDataLength);

            for (uint256 i = 0; i < compressedDstSwapDataLength; i++) {
                compressedDstSwapData[i] = response[64 + i];
            }
        }
    }

    /**
     * @notice Internal helper function to updated destination storage data
     * @param response the CLF response that contains the data
     */
    function _handleSrcFunctionsResponse(bytes memory response) internal {
        (
            uint256 dstGasPrice,
            uint256 srcGasPrice,
            uint64 dstChainSelector,
            uint256 linkUsdcRate,
            uint256 nativeUsdcRate,
            uint256 linkNativeRate
        ) = abi.decode(response, (uint256, uint256, uint64, uint256, uint256, uint256));

        if (srcGasPrice != 0) {
            s_lastGasPrices[i_chainSelector] = srcGasPrice;
        }

        if (dstGasPrice != 0) {
            s_lastGasPrices[dstChainSelector] = dstGasPrice;
        }

        if (linkUsdcRate != 0) {
            s_latestLinkUsdcRate = linkUsdcRate;
        }

        if (nativeUsdcRate != 0) {
            s_latestNativeUsdcRate = nativeUsdcRate;
        }

        if (linkNativeRate != 0) {
            s_latestLinkNativeRate = linkNativeRate;
        }
    }

    /* VIEW & PURE FUNCTIONS */
    /**
     * @notice Helper function to convert swapData into bytes payload to be sent through functions
     * @param _swapData The array of swap data
     */
    //    function _swapDataToBytes(
    //        IDexSwap.SwapData[] memory _swapData
    //    ) internal pure returns (bytes memory _encodedData) {
    //        if (_swapData.length == 0) {
    //            _encodedData = new bytes(1);
    //        } else {
    //            _encodedData = abi.encode(_swapData);
    //        }
    //    }

    /**
     * @notice getter function to calculate Destination fee amount on Source
     * @param amount the amount of tokens to calculate over
     * @return the fee amount
     */
    function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
        return (amount * PRECISION_HANDLER) / LP_FEE_FACTOR / PRECISION_HANDLER;
    }
}

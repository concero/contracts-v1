// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {Storage} from "./Libraries/Storage.sol";
import {IConceroPool} from "./Interfaces/IConceroPool.sol";

  ////////////////////////////////////////////////////////
  //////////////////////// ERRORS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice error emitted when a TX was already added
  error TXAlreadyExists(bytes32 txHash, bool isConfirmed);
  ///@notice error emitted when a unexpected ID is added
  error UnexpectedRequestID(bytes32);
  ///@notice error emitted when a transaction does not exist
  error TxDoesNotExist();
  ///@notice error emitted when a transaction was already confirmed
  error TxAlreadyConfirmed();
  ///@notice error emitted when function receive a call from a not allowed address
  error AddressNotSet();
  ///@notice error emitted when an arbitrary address calls fulfillRequestWrapper
  error ConceroFunctions_ItsNotOrchestrator(address caller);

contract ConceroFunctions is FunctionsClient, Storage {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  using SafeERC20 for IERC20;
  using FunctionsRequest for FunctionsRequest.Request;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice
  uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  ///@notice
  uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000;
  ///@notice
  uint8 internal constant CL_SRC_RESPONSE_LENGTH = 192;
  ///@notice JS Code for Chainlink Functions
  string internal constant CL_JS_CODE =
    "try { const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js'; const [t, p] = await Promise.all([ fetch(u), fetch( `https://raw.githubusercontent.com/concero/contracts-ccip/full-infra-functions/packages/hardhat/tasks/CLFScripts/dist/${BigInt(bytesArgs[2]) === 1n ? 'DST' : 'SRC'}.min.js`, ), ]); const [e, c] = await Promise.all([t.text(), p.text()]); const g = async s => { return ( '0x' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))) .map(v => ('0' + v.toString(16)).slice(-2).toLowerCase()) .join('') ); }; const r = await g(c); const x = await g(e); const b = bytesArgs[0].toLowerCase(); const o = bytesArgs[1].toLowerCase(); if (r === b && x === o) { const ethers = new Function(e + '; return ethers;')(); return await eval(c); } throw new Error(`${r}!=${b}||${x}!=${o}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";
  

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Chainlink Function Don ID
  bytes32 private immutable i_donId;
  ///@notice Chainlink Functions Protocol Subscription ID
  uint64 private immutable i_subscriptionId;
  //@audit can't be immutable
  uint64 immutable CHAIN_SELECTOR;
  ///@notice variable to store the DexSwap address
  address immutable i_dexSwap;
  ///@notice variable to store the ConceroPool address
  address immutable i_pool;
  ///@notice Immutable variable to hold proxy address
  address immutable i_proxy;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice emitted on source when a Unconfirmed TX is sent
  event UnconfirmedTXSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 dstChainSelector
  );
  ///@notice emitted when a Unconfirmed TX is added by a cross-chain TX
  event UnconfirmedTXAdded(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 srcChainSelector
  );
  event TXReleased(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    address token,
    uint256 amount
  );
  ///@notice emitted when on destination when a TX is validated.
  event TXConfirmed(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    uint256 amount,
    CCIPToken token
  );
  ///@notice emitted when a Function Request returns an error
  event FunctionsRequestError(bytes32 indexed ccipMessageId, bytes32 requestId, uint8 requestType);
  ///@notice emitted when the concero pool address is updated
  event ConceroPoolAddressUpdated(address previousAddress, address pool);
  ///@notice emitted when the secret version of Chainlink Function Don is updated
  event DonSecretVersionUpdated(uint64 previousDonSecretVersion, uint64 newDonSecretVersion);
  ///@notice emitted when the slot ID of Chainlink Function is updated
  event DonSlotIdUpdated(uint8 previousDonSlot, uint8 newDonSlot);
  ///@notice emitted when the source JS code of Chainlink Function is updated
  event SourceJsHashSumUpdated(bytes32 previousSrcHashSum, bytes32 newSrcHashSum);
  ///@notice emitted when the destination JS code of Chainlink Function is updated
  event DestinationJsHashSumUpdated(bytes32 previousDstHashSum, bytes32 newDstHashSum);
  ///@notice event emitted when the address for the Concero Contract is updated
  event ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  ///@notice event emitted when the Ethers HashSum is updated
  event EthersHashSumUpdated(bytes32 previousValue, bytes32 hashSum);

  constructor(
    FunctionsVariables memory _variables,
    uint64 _chainSelector,
    uint _chainIndex,
    JsCodeHashSum memory jsCodeHashSum,
    bytes32 ethersHashSum,
    address _dexSwap,
    address _pool,
    address _proxy
  ) FunctionsClient(_variables.functionsRouter){
    i_donId = _variables.donId;
    i_subscriptionId = _variables.subscriptionId;
    s_donHostedSecretsVersion = _variables.donHostedSecretsVersion;
    s_donHostedSecretsSlotId = _variables.donHostedSecretsSlotId;
    s_srcJsHashSum = jsCodeHashSum.src;
    s_dstJsHashSum = jsCodeHashSum.dst;
    s_ethersHashSum = ethersHashSum;
    CHAIN_SELECTOR = _chainSelector;
    s_chainIndex = Chain(_chainIndex);
    i_dexSwap = _dexSwap;
    i_pool = _pool;
    i_proxy = _proxy;
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////
  function setConceroContract(uint64 _chainSelector, address _conceroContract) external onlyOwner {
    s_conceroContracts[_chainSelector] = _conceroContract;

    emit ConceroContractUpdated(_chainSelector, _conceroContract);
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    uint64 previousValue = s_donHostedSecretsVersion;

    s_donHostedSecretsVersion = _version;

    emit DonSecretVersionUpdated(previousValue, _version);
  }

  function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external onlyOwner {
    uint8 previousValue = s_donHostedSecretsSlotId;

    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;

    emit DonSlotIdUpdated(previousValue, _donHostedSecretsSlotId);
  }

  function setDstJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_dstJsHashSum = _hashSum;

    emit DestinationJsHashSumUpdated(previousValue, _hashSum);
  }

  function setSrcJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_srcJsHashSum = _hashSum;

    emit SourceJsHashSumUpdated(previousValue, _hashSum);
  }

  function setEthersHashSum(bytes32 _hashSum) external payable onlyOwner {
    bytes32 previousValue = s_ethersHashSum;
    s_ethersHashSum = _hashSum;
    emit EthersHashSumUpdated(previousValue, _hashSum);
  }

  function addUnconfirmedTX(
    bytes32 ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    uint64 srcChainSelector,
    CCIPToken token,
    uint256 blockNumber
  ) external onlyMessenger {
    Transaction memory transaction = s_transactions[ccipMessageId];
    if (transaction.sender != address(0)) revert TXAlreadyExists(ccipMessageId, transaction.isConfirmed);

    s_transactions[ccipMessageId] = Transaction(ccipMessageId, sender, recipient, amount, token, srcChainSelector, false);

    bytes[] memory args = new bytes[](12);
    args[0] = abi.encodePacked(s_dstJsHashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);
    args[2] = abi.encodePacked(RequestType.checkTxSrc);
    args[3] = abi.encodePacked(s_conceroContracts[srcChainSelector]);
    args[4] = abi.encodePacked(srcChainSelector);
    args[5] = abi.encodePacked(blockNumber);
    args[6] = abi.encodePacked(ccipMessageId);
    args[7] = abi.encodePacked(sender);
    args[8] = abi.encodePacked(recipient);
    args[9] = abi.encodePacked(uint8(token));
    args[10] = abi.encodePacked(amount);
    args[11] = abi.encodePacked(CHAIN_SELECTOR);

    bytes32 reqId = sendRequest(args, CL_JS_CODE);

    s_requests[reqId].requestType = RequestType.checkTxSrc;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  /**
   * @notice Function to send a Request to Chainlink Functions
   * @param args the arguments for the request as bytes array
   * @param jsCode the JScode that will be executed.
   */
  function sendRequest(bytes[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
    req.setBytesArgs(args);
    return _sendRequest(req.encodeCBOR(), i_subscriptionId, CL_FUNCTIONS_CALLBACK_GAS_LIMIT, i_donId);
  }

  function fulfillRequestWrapper(bytes32 requestId, bytes memory response, bytes memory err) external {
    if(address(this) != i_proxy) revert ConceroFunctions_ItsNotOrchestrator(msg.sender);
    
    fulfillRequest(requestId, response, err);
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    Request storage request = s_requests[requestId];

    if (!request.isPending) {
      revert UnexpectedRequestID(requestId);
    }

    request.isPending = false;

    if (err.length > 0) {
      emit FunctionsRequestError(request.ccipMessageId, requestId, uint8(request.requestType));
      return;
    }

    if (request.requestType == RequestType.checkTxSrc) {
      _handleDstFunctionsResponse(request);
    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      _handleSrcFunctionsResponse(response);
    }
  }

  ////////////////////////
  ///INTERNAL FUNCTIONS///
  ////////////////////////
  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    if (transaction.sender == address(0)) revert TxDoesNotExist();
    if (transaction.isConfirmed == true) revert TxAlreadyConfirmed();

    transaction.isConfirmed = true;

    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }

  function sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, CCIPToken token) internal {
    if (s_conceroContracts[dstChainSelector] == address(0)) revert AddressNotSet();

    bytes[] memory args = new bytes[](12);
    args[0] = abi.encodePacked(s_srcJsHashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);
    args[2] = abi.encodePacked(RequestType.addUnconfirmedTxDst);
    args[3] = abi.encodePacked(s_conceroContracts[dstChainSelector]);
    args[4] = abi.encodePacked(ccipMessageId);
    args[5] = abi.encodePacked(sender);
    args[6] = abi.encodePacked(recipient);
    args[7] = abi.encodePacked(amount);
    args[8] = abi.encodePacked(CHAIN_SELECTOR);
    args[9] = abi.encodePacked(dstChainSelector);
    args[10] = abi.encodePacked(uint8(token));
    args[11] = abi.encodePacked(block.number);

    bytes32 reqId = sendRequest(args, CL_JS_CODE);
    s_requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }

  function _handleDstFunctionsResponse(Request storage request) internal {
    Transaction storage transaction = s_transactions[request.ccipMessageId];

    _confirmTX(request.ccipMessageId, transaction);

    uint256 amount = transaction.amount - getDstTotalFeeInUsdc(transaction.amount);
    address tokenReceived = getToken(transaction.token, s_chainIndex);

    //@audit hardcode for CCIP-BnM - Should be USDC
    //@audit s_chainIndex should be this way? Is there a better way to do it?
    if (tokenReceived == getToken(CCIPToken.bnm, s_chainIndex)) {
      IConceroPool(i_pool).orchestratorLoan(tokenReceived, amount, transaction.recipient);

      emit TXReleased(request.ccipMessageId, transaction.sender, transaction.recipient, tokenReceived, amount);
    } else {
      //@audit We need to call the DEX module here.
      // i_dexSwap.conceroEntry(passing the user address as receiver);
    }
  }

  function _handleSrcFunctionsResponse(bytes memory response) internal {
    if (response.length != CL_SRC_RESPONSE_LENGTH) {
      return;
    }

    (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector, uint256 linkUsdcRate, uint256 nativeUsdcRate, uint256 linkNativeRate) = abi.decode(
      response,
      (uint256, uint256, uint256, uint256, uint256, uint256)
    );

    s_lastGasPrices[CHAIN_SELECTOR] = srcGasPrice;
    s_lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    s_latestLinkUsdcRate = linkUsdcRate;
    s_latestNativeUsdcRate = nativeUsdcRate;
    s_latestLinkNativeRate = linkNativeRate;
  }
  
  function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
    return amount / 1000;
    //@audit we can have loss of precision here?
  }
}

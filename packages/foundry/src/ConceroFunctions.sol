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
  using Strings for uint256;
  using Strings for uint64;
  using Strings for address;
  using Strings for bytes32;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///////////////
  ///CONSTANTS///
  ///////////////
  uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000;
  ///@notice JS Code for source checking
  string internal constant srcJsCode =
    "try { await import('npm:ethers@6.10.0'); const crypto = await import('node:crypto'); const hash = crypto.createHash('sha256').update(secrets.SRC_JS, 'utf8').digest('hex'); if ('0x' + hash.toLowerCase() === args[0].toLowerCase()) { return await eval(secrets.SRC_JS); } else { throw new Error(`0x${hash.toLowerCase()} != ${args[0].toLowerCase()}`); } } catch (err) { throw new Error(err.message.slice(0, 255));}";
  ///@notice JS Code for destination checking
  string internal constant dstJsCode =
    "try { await import('npm:ethers@6.10.0'); const crypto = await import('node:crypto'); const hash = crypto.createHash('sha256').update(secrets.DST_JS, 'utf8').digest('hex'); if ('0x' + hash.toLowerCase() === args[0].toLowerCase()) { return await eval(secrets.DST_JS); } else { throw new Error(`0x${hash.toLowerCase()} != ${args[0].toLowerCase()}`); } } catch (err) { throw new Error(err.message.slice(0, 255));}";

  ////////////////
  ///IMMUTABLES///
  ////////////////
  bytes32 private immutable i_donId;
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

  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint8 _donHostedSecretsSlotId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex,
    JsCodeHashSum memory jsCodeHashSum,
    address _dexSwap,
    address _pool,
    address _proxy
  ) FunctionsClient(_functionsRouter){
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    s_donHostedSecretsVersion = _donHostedSecretsVersion;
    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;
    s_srcJsHashSum = jsCodeHashSum.src;
    s_dstJsHashSum = jsCodeHashSum.dst;
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

  //@audit if updated to bytes[] memory. We can remove this guys
  function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
    bytes32 out;
    for (uint i = 0; i < 32; i++) {
      out |= bytes32(b[i] & 0xFF) >> (i * 8);
    }
    return out;
  }

  //@audit if updated to bytes[] memory. We can remove this guys
  function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
    bytes memory chars = "0123456789abcdef";
    bytes memory str = new bytes(64);
    for (uint256 i = 0; i < 32; i++) {
      bytes1 b = _bytes32[i];
      str[i * 2] = chars[uint8(b) >> 4];
      str[i * 2 + 1] = chars[uint8(b) & 0x0f];
    }
    return string(abi.encodePacked("0x", str));
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

    //@audit bytes[] memory args = new bytes[](9)
    string[] memory args = new string[](10);
    //todo: use bytes
    //@audit = abi.encode(param);
    args[0] = bytes32ToString(s_dstJsHashSum);
    args[1] = Strings.toHexString(s_conceroContracts[srcChainSelector]);
    args[2] = Strings.toString(srcChainSelector);
    args[3] = Strings.toHexString(blockNumber);
    args[4] = bytes32ToString(ccipMessageId);
    args[5] = Strings.toHexString(sender);
    args[6] = Strings.toHexString(recipient);
    args[7] = Strings.toString(uint(token));
    args[8] = Strings.toString(amount);
    args[9] = Strings.toString(CHAIN_SELECTOR);

    bytes32 reqId = sendRequest(args, dstJsCode);

    s_requests[reqId].requestType = RequestType.checkTxSrc;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  //@audit I think we can send bytes[] memory args instead of string[] memory args.
  //I just don't know yet if we need to pass anything different besides the setArgs function.
  function sendRequest(string[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
    req.setArgs(args);
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
      Transaction storage transaction = s_transactions[request.ccipMessageId];

      _confirmTX(request.ccipMessageId, transaction);

      uint256 amount = transaction.amount - getDstTotalFeeInUsdc(transaction.amount);

      address tokenReceived = getToken(transaction.token, s_chainIndex);

      if (tokenReceived == getToken(CCIPToken.bnm, s_chainIndex)) {
        //@audit hardcode for CCIP-BnM - Should be USDC

        IConceroPool(i_pool).orchestratorLoan(tokenReceived, amount, transaction.recipient);
      } else {
        //@audit We need to call the DEX module here.
        // i_dexSwap.conceroEntry(passing the user address as receiver);
      }
    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      //@audit what means this 96?
      if (response.length != 96) {
        return;
      }

      (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector) = abi.decode(response, (uint256, uint256, uint256));

      s_lastGasPrices[CHAIN_SELECTOR] = srcGasPrice;
      s_lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    }
  }

  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    if (transaction.sender == address(0)) revert TxDoesNotExist();
    if (transaction.isConfirmed == true) revert TxAlreadyConfirmed();

    transaction.isConfirmed = true;

    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }

  function sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, CCIPToken token) internal {
    if (s_conceroContracts[dstChainSelector] == address(0)) revert AddressNotSet();

    string[] memory args = new string[](10);
    //todo: Strings usage may not be required here. Consider ways of passing data without converting to string
    args[0] = bytes32ToString(s_srcJsHashSum);
    args[1] = Strings.toHexString(s_conceroContracts[dstChainSelector]);
    args[2] = bytes32ToString(ccipMessageId);
    args[3] = Strings.toHexString(sender);
    args[4] = Strings.toHexString(recipient);
    args[5] = Strings.toString(amount);
    args[6] = Strings.toString(CHAIN_SELECTOR);
    args[7] = Strings.toString(dstChainSelector);
    args[8] = Strings.toString(uint256(token));
    args[9] = Strings.toHexString(block.number);

    bytes32 reqId = sendRequest(args, srcJsCode);
    s_requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }
  
  function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
    return amount / 1000;
    //@audit we can have loss of precision here?
  }
}

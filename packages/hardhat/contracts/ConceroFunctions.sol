// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IFunctions} from "./IConcero.sol";
import {Concero} from "./Concero.sol";
import {ConceroCommon} from "./ConceroCommon.sol";

contract ConceroFunctions is FunctionsClient, IFunctions, ConceroCommon {
  using FunctionsRequest for FunctionsRequest.Request;
  using Strings for uint256;
  using Strings for uint64;
  using Strings for address;
  using Strings for bytes32;

  bytes32 private immutable donId;
  uint64 private immutable subscriptionId;
  uint8 private donHostedSecretsSlotID;
  uint64 private donHostedSecretsVersion;

  mapping(bytes32 => Transaction) public transactions;
  mapping(bytes32 => Request) public requests;

  string private constant srcJsCode =
    "try { const ethers = await import('npm:ethers@6.10.0'); const [ dstContractAddress, ccipMessageId, sender, recipient, amount, srcChainSelector, dstChainSelector, token, blockNumber, ] = args; const chainSelectors = { '14767482510784806043': { url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`, chainId: '0xa869', }, '16015286601757825753': { url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, chainId: '0xaa36a7', }, '3478487238524512106': { url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, chainId: '0x66eee', }, '10344971235874465080': { url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`, chainId: '0x14a34', }, '5224473277236331295': { url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, chainId: '0xaa37dc', }, }; class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider { constructor(url) { super(url); this.url = url; } async _send(payload) { if (payload.method === 'eth_estimateGas') { return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}]; } if (payload.method === 'eth_chainId') { return [{jsonrpc: '2.0', id: payload.id, result: chainSelectors[dstChainSelector].chainId}]; } let resp = await fetch(this.url, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload), }); return resp.json(); } } const abi = ['function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external']; const provider = new FunctionsJsonRpcProvider(chainSelectors[dstChainSelector].url); const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider); const signer = wallet.connect(provider); const contract = new ethers.Contract(dstContractAddress, abi, signer); const tx = await contract.addUnconfirmedTX( ccipMessageId, sender, recipient, amount, srcChainSelector, token, blockNumber, ); return Functions.encodeString(tx.hash); } catch (error) { if (error.message === 'already known') { return Functions.encodeString('already known'); } throw new Error(error.message.slice(0, 255));}";
  string private constant dstJsCode =
    "const ethers = await import('npm:ethers@6.10.0'); const [srcContractAddress, srcChainSelector, _, ...eventArgs] = args; const messageId = eventArgs[0]; const chainMap = { '14767482510784806043': { url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`, }, '16015286601757825753': { url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, }, '3478487238524512106': { url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, }, '10344971235874465080': { url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`, }, '5224473277236331295': { url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, }, }; const latestBlockParams = { url: chainMap[srcChainSelector].url, method: 'POST', headers: { 'Content-Type': 'application/json', }, data: { jsonrpc: '2.0', method: 'eth_blockNumber', id: 1, }, }; const {data: latestBlockData} = await Functions.makeHttpRequest(latestBlockParams); if (latestBlockData.error) { throw new Error(latestBlockData.error.message); } if (!latestBlockData.result.length) { throw new Error('Latest block not found'); } const toBlock = latestBlockData.result; const fromBlock = BigInt(toBlock) - 1000n; const params = { url: chainMap[srcChainSelector].url, method: 'POST', headers: { 'Content-Type': 'application/json', }, data: { jsonrpc: '2.0', method: 'eth_getLogs', id: 1, params: [ { address: srcContractAddress, topics: [null, messageId], fromBlock: `0x${fromBlock.toString(16)}`, toBlock: 'latest', }, ], }, }; const {data} = await Functions.makeHttpRequest(params); if (data.error) { throw new Error(data.error.message); } if (!data.result.length) { throw new Error('Logs not found'); } const abi = ['event CCIPSent(bytes32 indexed, address, address, uint8, uint256, uint64)']; const contract = new ethers.Interface(abi); const log = { topics: [ethers.id('CCIPSent(bytes32,address,address,uint8,uint256,uint64)'), data.result[0].topics[1]], data: data.result[0].data, }; const decodedLog = contract.parseLog(log); for (let i = 0; i < decodedLog.length; i++) { if (decodedLog.args[i].toString().toLowerCase() !== eventArgs[i].toString().toLowerCase()) { throw new Error('Message ID does not match the event log'); } } return Functions.encodeUint256(BigInt(messageId));";

  modifier onlyMessenger() {
    if (!messengerContracts[msg.sender]) revert NotMessenger(msg.sender);
    _;
  }

  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex
  ) FunctionsClient(_functionsRouter) ConceroCommon(_chainSelector, _chainIndex) {
    donId = _donId;
    subscriptionId = _subscriptionId;
    donHostedSecretsVersion = _donHostedSecretsVersion;
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    donHostedSecretsVersion = _version;
  }

  function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
    bytes32 out;
    for (uint i = 0; i < 32; i++) {
      out |= bytes32(b[i] & 0xFF) >> (i * 8);
    }
    return out;
  }

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
    Transaction storage transaction = transactions[ccipMessageId];
    if (transaction.sender != address(0)) revert TXAlreadyExists(ccipMessageId, transaction.isConfirmed);
    transactions[ccipMessageId] = Transaction(ccipMessageId, sender, recipient, amount, token, srcChainSelector, false);

    string[] memory args = new string[](9);
    //todo: use bytes
    args[0] = Strings.toHexString(conceroContracts[srcChainSelector]);
    args[1] = Strings.toString(srcChainSelector);
    args[2] = Strings.toHexString(blockNumber);
    args[3] = bytes32ToString(ccipMessageId);
    args[4] = Strings.toHexString(sender);
    args[5] = Strings.toHexString(recipient);
    args[6] = Strings.toString(uint(token));
    args[7] = Strings.toString(amount);
    args[8] = Strings.toString(chainSelector);

    bytes32 reqId = sendRequest(args, dstJsCode);
    requests[reqId].requestType = RequestType.checkTxSrc;
    requests[reqId].isPending = true;
    requests[reqId].ccipMessageId = ccipMessageId;
    emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  function sendRequest(string[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
    req.setArgs(args);
    return _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    Request storage request = requests[requestId];

    if (!request.isPending) {
      revert UnexpectedRequestID(requestId);
    }

    request.isPending = false;
    if (err.length > 0) {
      emit FunctionsRequestError(request.ccipMessageId, requestId, uint8(request.requestType));
      return;
    }

    if (request.requestType == RequestType.checkTxSrc) {
      bytes32 ccipMessageId = bytesToBytes32(response);
      Transaction storage transaction = transactions[ccipMessageId];
      _confirmTX(ccipMessageId, transaction);
      sendTokenToEoa(ccipMessageId, transaction.sender, transaction.recipient, getToken(transaction.token), transaction.amount);
    }
  }

  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    require(transaction.sender != address(0), "TX does not exist");
    require(!transaction.isConfirmed, "TX already confirmed");
    transaction.isConfirmed = true;
    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }

  function sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, CCIPToken token) internal {
    if (conceroContracts[dstChainSelector] == address(0)) revert("address not set");

    string[] memory args = new string[](9);
    //todo: Strings usage may not be required here. Consider ways of passing data without converting to string
    args[0] = Strings.toHexString(conceroContracts[dstChainSelector]);
    args[1] = bytes32ToString(ccipMessageId);
    args[2] = Strings.toHexString(sender);
    args[3] = Strings.toHexString(recipient);
    args[4] = Strings.toString(amount);
    args[5] = Strings.toString(chainSelector);
    args[6] = Strings.toString(dstChainSelector);
    args[7] = Strings.toString(uint(token));
    args[8] = Strings.toHexString(block.number);

    bytes32 reqId = sendRequest(args, srcJsCode);
    requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    requests[reqId].isPending = true;
    requests[reqId].ccipMessageId = ccipMessageId;
    emit UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }

  function sendTokenToEoa(bytes32 _ccipMessageId, address _sender, address _recipient, address _token, uint256 _amount) internal {
    bool isOk = IERC20(_token).transfer(_recipient, _amount);
    if (isOk) {
      emit TXReleased(_ccipMessageId, _sender, _recipient, _token, _amount);
    } else {
      emit TXReleaseFailed(_ccipMessageId, _sender, _recipient, _token, _amount);
      revert SendTokenFailed(_ccipMessageId, _token, _amount, _recipient);
    }
  }
}

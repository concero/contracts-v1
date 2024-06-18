// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {ChildStorage} from "contracts/Libraries/ChildStorage.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the balance is not sufficient
error ConceroChildPool_InsufficientBalance();
///@notice error emitted when the CCIP message sender is not allowed.
error ConceroChildPool_SenderNotAllowed(address sender);
///@notice error emitted when an attempt to send value to a not allowed receiver is made
error ConceroChildPool_DestinationNotAllowed();
///@notice error emitted when the contract doesn't have enough link balance
error ConceroChildPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when the caller is not the messenger
error ConceroChildPool_NotMessenger(address caller);
///@notice error emitted when the chain selector input is invalid
error ConceroChildPool_ChainNotAllowed(uint64 chainSelector);
///@notice error emitted when the caller is not the Orchestrator
error ConceroChildPool_CallerIsNotTheProxy(address delegatedCaller);
///@notice error emitted when a not-concero address call orchestratorLoan
error ConceroChildPool_CallerIsNotConcero(address caller);
///@notice error emitted when the receiver is the address(0)
error ConceroChildPool_InvalidAddress();

contract ConceroChildPool is CCIPReceiver, ChildStorage {
  using SafeERC20 for IERC20;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Child Pool proxy address
  address private immutable i_childProxy;
  ///@notice Chainlink Link Token interface
  LinkTokenInterface private immutable i_linkToken;
  ///@notice Chainlink CCIP Router
  IRouterClient private immutable i_router;
  ///@notice immutable variable to store the USDC address.
  IERC20 immutable i_USDC;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Magic Number Removal
  uint256 private constant ALLOWED = 1;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Cross-chain tx is received.
  event ConceroChildPool_CCIPReceived(bytes32 indexed ccipMessageId, uint64 srcChainSelector, address sender, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain message is sent.
  event ConceroChildPool_MessageSent(bytes32 messageId, uint64 destinationChainSelector, address receiver, address linkToken, uint256 fees);
  ///@notice event emitted in OrchestratorLoan when a loan is taken
  event ConceroChildPool_LoanTaken(address receiver, uint256 amount);

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice CCIP Modifier to check Chains And senders
   * @param _chainSelector Id of the source chain of the message
   * @param _sender address of the sender contract
   */
  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (s_poolToReceiveFrom[_chainSelector][_sender] != ALLOWED) revert ConceroChildPool_SenderNotAllowed(_sender);
    _;
  }

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (getMessengers(msg.sender) == false) revert ConceroChildPool_NotMessenger(msg.sender);
    _;
  }

  /**
   * @notice CCIP Modifier to check receivers for a specific chain
   * @param _chainSelector Id of the destination chain
   */
  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_poolToSendTo[_chainSelector] == address(0)) revert ConceroChildPool_ChainNotAllowed(_chainSelector);
    _;
  }

  modifier isProxy() {
    if (address(this) != i_childProxy) revert ConceroChildPool_CallerIsNotTheProxy(address(this));
    _;
  }

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  receive() external payable {}

  constructor(address _childPool, address _link, address _ccipRouter, address _usdc, address _owner) CCIPReceiver(_ccipRouter) ChildStorage(_owner) {
    i_childProxy = _childPool;
    i_linkToken = LinkTokenInterface(_link);
    i_router = IRouterClient(_ccipRouter);
    i_USDC = IERC20(_usdc);
  }

  //@Oleg How to fit the withdraw requests in here?

  ////////////////////////
  ///EXTERNAL FUNCTIONS///
  ////////////////////////

  /**
   * @notice Function to Distribute Liquidity across Concero Pools
   * @param _destinationChainSelector Chain Id of the chain that will receive the amount
   * @param _liquidityProviderAddress The liquidity provider that requested Withdraw
   * @param _token  address of the token to be sent
   * @param _amount amount of the token to be sent
   * @dev This function will sent the address of the user as data. This address will be used to update the mapping on MasterPool.
   */
  function ccipSendToPool(
    uint64 _destinationChainSelector,
    address _liquidityProviderAddress,
    address _token,
    uint256 _amount
  ) external onlyMessenger isProxy onlyAllowListedChain(_destinationChainSelector) returns (bytes32 messageId) {
    if (s_poolToSendTo[_destinationChainSelector] == address(0)) revert ConceroChildPool_DestinationNotAllowed();
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroChildPool_InsufficientBalance();

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: _token, amount: _amount});

    tokenAmounts[0] = tokenAmount;

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(s_poolToSendTo[_destinationChainSelector]),
      data: abi.encode(_liquidityProviderAddress, 0), //0== lp fee. It will always be zero because here we just process withdraws
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
      feeToken: address(i_linkToken)
    });

    uint256 fees = i_router.getFee(_destinationChainSelector, evm2AnyMessage);

    if (fees > i_linkToken.balanceOf(address(this))) revert ConceroChildPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

    IERC20(_token).approve(address(i_router), _amount);
    i_linkToken.approve(address(i_router), fees);

    emit ConceroChildPool_MessageSent(messageId, _destinationChainSelector, s_poolToSendTo[_destinationChainSelector], address(i_linkToken), fees);

    messageId = i_router.ccipSend(_destinationChainSelector, evm2AnyMessage);
  }

  /**
   * @notice function to the Concero Orchestrator contract take loans
   * @param _token address of the token being loaned
   * @param _amount being loaned
   * @param _receiver address of the user that will receive the amount
   * @dev only the Orchestrator contract should be able to call this function
   * @dev for ether transfer, the _receiver need to be known and trusted
   */
  function orchestratorLoan(address _token, uint256 _amount, address _receiver) external isProxy {
    if (msg.sender != s_concero) revert ConceroChildPool_CallerIsNotConcero(msg.sender);
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroChildPool_InsufficientBalance();
    if (_receiver == address(0)) revert ConceroChildPool_InvalidAddress();

    s_commits = s_commits + _amount;

    IERC20(_token).safeTransfer(_receiver, _amount);

    emit ConceroChildPool_LoanTaken(_receiver, _amount);
  }

  ////////////////
  /// INTERNAL ///
  ////////////////
  /**
   * @notice CCIP function to receive bridged values
   * @param any2EvmMessage the CCIP message
   * @dev only allowed chains and sender must be able to deliver a message in this function.
   */
  function _ccipReceive(
    Client.Any2EVMMessage memory any2EvmMessage
  ) internal override onlyAllowlistedSenderAndChainSelector(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) {
    (/*address liquidityProvider*/, uint256 receivedFee) = abi.decode(any2EvmMessage.data, (address, uint256));

    if (receivedFee > 0) {
      //subtract the amount from the committed total amount
      s_commits = s_commits - (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);
    }

    emit ConceroChildPool_CCIPReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector,
      abi.decode(any2EvmMessage.sender, (address)),
      any2EvmMessage.destTokenAmounts[0].token,
      any2EvmMessage.destTokenAmounts[0].amount
    );
  }

  ///////////////
  /// PRIVATE ///
  ///////////////

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////

  /**
   * @notice Function to check if a caller address is an allowed messenger
   * @param _messenger the address of the caller
   */
  function getMessengers(address _messenger) internal pure returns (bool isMessenger) {
    address[] memory messengers = new address[](4); //Number of messengers. To define.
    messengers[0] = address(0);
    messengers[1] = address(0);
    messengers[2] = address(0);
    messengers[3] = address(0);

    for (uint256 i; i < messengers.length; ) {
      if (_messenger == messengers[i]) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }
}

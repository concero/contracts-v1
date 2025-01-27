// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity ^0.8.22;

import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {ChildPoolStorage} from "./Libraries/ChildPoolStorage.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ICCIP} from "./Interfaces/ICCIP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInfraOrchestrator} from "./Interfaces/IInfraOrchestrator.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* ERRORS */
///@notice error emitted when the caller is not the Orchestrator
error CallerIsNotTheProxy(address delegatedCaller);
error Unauthorized();
///@notice error emitted when the receiver is the address(0)
error InvalidAddress();
///@notice error emitted when the caller is a non-messenger address
error NotMessenger();
///@notice error emitted when the caller is not the owner of the contract
error NotOwner();
///@notice error emitted if the array is empty.
error NoPoolsToDistribute();
error DistributeLiquidityRequestAlreadyProceeded(bytes32 reqId);
error WithdrawalAlreadyTriggered();
error NotUsdcToken();
error NotConceroInfraProxy();

contract ChildPool is CCIPReceiver, ChildPoolStorage {
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint32 public constant CLF_CALLBACK_GAS_LIMIT = 300_000;
    uint32 private constant CCIP_SEND_GAS_LIMIT = 300_000;
    uint256 internal constant PRECISION_HANDLER = 10_000_000_000;
    uint256 internal constant LP_FEE_FACTOR = 1000;

    /* IMMUTABLE VARIABLES */
    address private immutable i_infraProxy;
    address private immutable i_childProxy;
    LinkTokenInterface private immutable i_linkToken;
    IERC20 private immutable i_USDC;
    address private immutable i_owner;
    address private immutable i_msgr0;
    address private immutable i_msgr1;
    address private immutable i_msgr2;

    /* EVENTS */
    event FailedExecutionLayerTxSettled(bytes32 indexed conceroMessageId);
    ///@notice event emitted when a Cross-chain tx is received.
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );
    ///@notice event emitted when a Cross-chain message is sent.
    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        address linkToken,
        uint256 fees
    );

    /* MODIFIERS */
    /**
     * @notice modifier to ensure if the function is being executed in the proxy context.
     */
    modifier onlyProxyContext() {
        if (address(this) != i_childProxy) {
            revert CallerIsNotTheProxy(address(this));
        }
        _;
    }

    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        if (!_isMessenger(msg.sender)) revert NotMessenger();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    /**
     * @notice CCIP Modifier to check Chains And senders
     * @param _chainSelector Id of the source chain of the message
     * @param _sender address of the sender contract
     */
    modifier onlyAllowlistedSenderOfChainSelector(uint64 _chainSelector, address _sender) {
        if (!s_isSenderContractAllowed[_chainSelector][_sender]) {
            revert Unauthorized();
        }
        _;
    }

    /* FUNCTIONS */
    receive() external payable {}

    constructor(
        address _infraProxy,
        address _proxy,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _owner,
        address[3] memory _messengers
    ) CCIPReceiver(_ccipRouter) {
        i_infraProxy = _infraProxy;
        i_childProxy = _proxy;
        i_linkToken = LinkTokenInterface(_link);
        i_USDC = IERC20(_usdc);
        i_owner = _owner;
        i_msgr0 = _messengers[0];
        i_msgr1 = _messengers[1];
        i_msgr2 = _messengers[2];
    }

    /* EXTERNAL FUNCTIONS */

    /**
     * @notice Function called by Messenger to process withdrawal requests
     * @param _chainSelector The destination chain selector will always be from Parent Pool
     * @param _amountToSend the amount to redistribute between pools.
     * @param _withdrawalId the id of the withdraw request
     */
    function ccipSendToPool(
        uint64 _chainSelector,
        uint256 _amountToSend,
        bytes32 _withdrawalId
    ) external onlyProxyContext onlyMessenger {
        if (s_dstPoolByChainSelector[_chainSelector] == address(0)) revert InvalidAddress();
        if (s_isWithdrawalRequestTriggered[_withdrawalId]) {
            revert WithdrawalAlreadyTriggered();
        } else {
            s_isWithdrawalRequestTriggered[_withdrawalId] = true;
        }

        ICCIP.CcipTxData memory ccipTxData = ICCIP.CcipTxData({
            ccipTxType: ICCIP.CcipTxType.withdrawal,
            data: abi.encode(_withdrawalId)
        });

        _ccipSend(_chainSelector, _amountToSend, ccipTxData);
    }

    /**
     * @notice Function called by Messenger to send USDC to a recently added pool.
     * @param _chainSelector The chain selector of the new pool
     * @param _amountToSend the amount to redistribute between pools.
     */
    function distributeLiquidity(
        uint64 _chainSelector,
        uint256 _amountToSend,
        bytes32 _requestId
    ) external onlyProxyContext onlyMessenger {
        if (s_dstPoolByChainSelector[_chainSelector] == address(0)) revert InvalidAddress();
        if (s_distributeLiquidityRequestProcessed[_requestId] != false) {
            revert DistributeLiquidityRequestAlreadyProceeded(_requestId);
        } else {
            s_distributeLiquidityRequestProcessed[_requestId] = true;
        }
        ICCIP.CcipTxData memory _ccipTxData = ICCIP.CcipTxData({
            ccipTxType: ICCIP.CcipTxType.liquidityRebalancing,
            data: bytes("")
        });

        _ccipSend(_chainSelector, _amountToSend, _ccipTxData);
    }

    /**
     * @notice helper function to remove and distribute liquidity when a pool is removed.
     * @dev this functions should be called only if there is no transaction being processed
     * @dev If Orchestrator took a loan and the money didn't rebalance yet, it will be left behind.
     */
    function liquidatePool(
        bytes32 distributeLiquidityRequestId
    ) external onlyProxyContext onlyMessenger {
        if (s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId]) {
            revert DistributeLiquidityRequestAlreadyProceeded(distributeLiquidityRequestId);
        } else {
            s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] = true;
        }

        uint256 poolsCount = s_poolChainSelectors.length;
        if (poolsCount == 0) revert NoPoolsToDistribute();

        uint256 amountToSendPerPool = (i_USDC.balanceOf(address(this)) / poolsCount) - 1;
        ICCIP.CcipTxData memory ccipTxData = ICCIP.CcipTxData({
            ccipTxType: ICCIP.CcipTxType.liquidityRebalancing,
            data: bytes("")
        });

        for (uint256 i; i < poolsCount; i++) {
            //This is a function to deal with adding&removing pools. So, the second param will always be address(0)
            _ccipSend(s_poolChainSelectors[i], amountToSendPerPool, ccipTxData);
        }
    }

    /**
     * @notice function for Concero Orchestrator contract to take loans
     * @param _token address of the token being loaned
     * @param _amount being loaned
     * @param _receiver address of the user that will receive the amount
     * @dev only the Orchestrator contract should be able to call this function
     * @dev for ether transfer, the _receiver need to be known and trusted
     */
    function takeLoan(
        address _token,
        uint256 _amount,
        address _receiver
    ) external onlyProxyContext {
        if (msg.sender != i_infraProxy) revert NotConceroInfraProxy();
        if (_receiver == address(0)) revert InvalidAddress();
        if (_token != address(i_USDC)) revert NotUsdcToken();
        IERC20(_token).safeTransfer(_receiver, _amount);
        s_loansInUse += _amount;
    }

    /* SETTER FUNCTIONS */
    /**
     * @notice function to manage the Cross-chains Concero contracts
     * @param _chainSelector chain identifications
     * @param _contractAddress address of the Cross-chains Concero contracts
     * @param _isAllowed bool to allow or disallow the contract to send ccip messages
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     */
    function setConceroContractSender(
        uint64 _chainSelector,
        address _contractAddress,
        bool _isAllowed
    ) external payable onlyOwner {
        if (_contractAddress == address(0)) revert InvalidAddress();
        s_isSenderContractAllowed[_chainSelector][_contractAddress] = _isAllowed;
    }

    /**
     * @notice function to manage the Cross-chain ConceroPool contracts
     * @param _chainSelector chain identifications
     * @param _pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     */
    function setPools(uint64 _chainSelector, address _pool) external payable onlyOwner {
        if (s_dstPoolByChainSelector[_chainSelector] == _pool || _pool == address(0)) {
            revert InvalidAddress();
        }

        s_poolChainSelectors.push(_chainSelector);
        s_dstPoolByChainSelector[_chainSelector] = _pool;
    }

    /**
     * @notice Function to remove Cross-chain address disapproving transfers
     * @param _chainSelector the CCIP chainSelector for the specific chain
     */
    function removePools(uint64 _chainSelector) external payable onlyOwner {
        for (uint256 i; i < s_poolChainSelectors.length; i++) {
            if (s_poolChainSelectors[i] == _chainSelector) {
                s_poolChainSelectors[i] = s_poolChainSelectors[s_poolChainSelectors.length - 1];
                s_poolChainSelectors.pop();
                delete s_dstPoolByChainSelector[_chainSelector];
            }
        }
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice CCIP function to receive bridged values
     * @param any2EvmMessage the CCIP message
     * @dev only allowed chains and sender must be able to deliver a message in this function.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlistedSenderOfChainSelector(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        ICCIP.CcipTxData memory ccipTxData = abi.decode(any2EvmMessage.data, (ICCIP.CcipTxData));
        uint256 ccipReceivedAmount = any2EvmMessage.destTokenAmounts[0].amount;
        address ccipReceivedToken = any2EvmMessage.destTokenAmounts[0].token;

        if (ccipReceivedToken != address(i_USDC)) {
            revert NotUsdcToken();
        }

        if (ccipTxData.ccipTxType == ICCIP.CcipTxType.batchedSettlement) {
            IConceroBridge.CcipSettlementTx[] memory settlementTxs = abi.decode(
                ccipTxData.data,
                (IConceroBridge.CcipSettlementTx[])
            );
            for (uint256 i; i < settlementTxs.length; ++i) {
                bytes32 txId = settlementTxs[i].id;
                uint256 txAmount = settlementTxs[i].amount;
                bool isTxConfirmed = IInfraOrchestrator(i_infraProxy).isTxConfirmed(txId);

                if (isTxConfirmed) {
                    txAmount -= getDstTotalFeeInUsdc(txAmount);
                    s_loansInUse -= txAmount;
                } else {
                    IInfraOrchestrator(i_infraProxy).confirmTx(txId);
                    i_USDC.safeTransfer(settlementTxs[i].recipient, txAmount);
                    emit FailedExecutionLayerTxSettled(settlementTxs[i].id);
                }
            }
        }

        emit CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            ccipReceivedToken,
            ccipReceivedAmount
        );
    }

    /**
     * @notice Function to Distribute Liquidity across Concero Pools and process withdrawals
     * @param _chainSelector the chainSelector of the pool to send the USDC
     * @param _amount amount of the token to be sent
     * @param ccipTxData the data to be sent to the pool
     * @dev This function will sent the address of the user as data. This address will be used to update the mapping on ParentPool.
     * @dev when processing withdrawals, the _chainSelector will always be the index 0 of s_poolChainSelectors
     */
    function _ccipSend(
        uint64 _chainSelector,
        uint256 _amount,
        ICCIP.CcipTxData memory ccipTxData
    ) internal returns (bytes32) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(i_USDC), amount: _amount});
        address destinationPool = s_dstPoolByChainSelector[_chainSelector];

        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationPool),
            data: abi.encode(ccipTxData),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: CCIP_SEND_GAS_LIMIT})),
            feeToken: address(i_linkToken)
        });

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(_chainSelector, evm2AnyMessage);

        i_USDC.approve(i_ccipRouter, _amount);
        i_linkToken.approve(i_ccipRouter, ccipFeeAmount);

        return IRouterClient(i_ccipRouter).ccipSend(_chainSelector, evm2AnyMessage);
    }

    /* VIEW & PURE FUNCTIONS */

    /**
     * @notice getter function to calculate Destination fee amount on Source
     * @param amount the amount of tokens to calculate over
     * @return the fee amount
     */
    function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
        return (amount * PRECISION_HANDLER) / LP_FEE_FACTOR / PRECISION_HANDLER;
    }

    /**
     * @notice Function to check if a caller address is an allowed messenger
     * @param _messenger the address of the caller
     */
    function _isMessenger(address _messenger) internal view returns (bool) {
        return (_messenger == i_msgr0 || _messenger == i_msgr1 || _messenger == i_msgr2);
    }
}

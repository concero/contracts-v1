// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ICCIP} from "./Interfaces/ICCIP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInfraOrchestrator} from "./Interfaces/IInfraOrchestrator.sol";
import {IInfraStorage} from "./Interfaces/IInfraStorage.sol";
import {IParentPoolCLFCLA, IParentPoolCLFCLAViewDelegate} from "./Interfaces/IParentPoolCLFCLA.sol";
import {IParentPool} from "./Interfaces/IParentPool.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ParentPoolCommon} from "./ParentPoolCommon.sol";
import {ParentPoolStorage} from "./Libraries/ParentPoolStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* ERRORS */
///@notice error emitted when the receiver is the address(0)
error InvalidAddress();
///@notice error emitted when the CCIP message sender is not allowed.
error SenderNotAllowed(address _sender);
error WithdrawalRequestAlreadyExists();
error DepositAmountBelowMinimum(uint256 minAmount);
error DepositRequestNotReady();
error DepositsOnTheWayArrayFull();
error WithdrawAmountBelowMinimum(uint256 minAmount);
///@notice error emitted when the caller is not the Orchestrator
error NotConceroInfraProxy();
///@notice error emitted when the max amount accepted by the pool is reached
error MaxDepositCapReached(uint256 maxCap);
error DistributeLiquidityRequestAlreadyProceeded(bytes32 requestId);
///@notice error emitted when the caller is not the LP who opened the request
error NotAllowedToCompleteDeposit();
///@notice error emitted when the request doesn't exist
error WithdrawRequestDoesntExist(bytes32 withdrawalId);
error NotOwner();
error OnlyRouterCanFulfill(address);
error Unauthorized();
error NotUsdcToken();
error DepositDeadlinePassed();

contract ParentPool is IParentPool, CCIPReceiver, ParentPoolCommon, ParentPoolStorage {
    /* TYPE DECLARATIONS */
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    //TODO: move testnet-mainnet-dependent variables to immutables
    uint256 internal constant MIN_DEPOSIT = 100 * USDC_DECIMALS;
    uint256 internal constant DEPOSIT_DEADLINE_SECONDS = 60;
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * USDC_DECIMALS;
    uint256 internal constant LP_FEE_FACTOR = 1000;
    uint32 private constant CCIP_SEND_GAS_LIMIT = 300_000;

    /* IMMUTABLE VARIABLES */
    address private immutable i_infraProxy;
    LinkTokenInterface private immutable i_linkToken;
    IParentPoolCLFCLA internal immutable i_parentPoolCLFCLA;
    address internal immutable i_owner;
    address internal immutable i_clfRouter;
    address internal immutable i_automationForwarder;

    /* MODIFIERS */
    /**
     * @notice CCIP Modifier to check Chains And senders
     * @param _chainSelector Id of the source chain of the message
     * @param _sender address of the sender contract
     */
    modifier onlyAllowlistedSenderOfChainSelector(uint64 _chainSelector, address _sender) {
        if (!s_isSenderContractAllowed[_chainSelector][_sender]) {
            revert SenderNotAllowed(_sender);
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    constructor(
        address _parentPoolProxy,
        address _parentPoolCLFCLA,
        address _automationForwarder,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _lpToken,
        address _infraProxy,
        address _clfRouter,
        address _owner,
        address[3] memory _messengers
    ) CCIPReceiver(_ccipRouter) ParentPoolCommon(_parentPoolProxy, _lpToken, _usdc, _messengers) {
        i_linkToken = LinkTokenInterface(_link);
        i_infraProxy = _infraProxy;
        i_owner = _owner;
        i_parentPoolCLFCLA = IParentPoolCLFCLA(_parentPoolCLFCLA);
        i_clfRouter = _clfRouter;
        i_automationForwarder = _automationForwarder;
    }

    /* EXTERNAL FUNCTIONS */
    receive() external payable {}

    function getWithdrawalIdByLPAddress(address _lpAddress) external view returns (bytes32) {
        return s_withdrawalIdByLPAddress[_lpAddress];
    }

    function getUsdcInUse() external view returns (uint256) {
        return s_loansInUse;
    }

    function getWithdrawalsOnTheWayAmount() external view returns (uint256) {
        return s_withdrawalsOnTheWayAmount;
    }

    function getDepositsOnTheWay()
        external
        view
        returns (DepositOnTheWay[MAX_DEPOSITS_ON_THE_WAY_COUNT] memory)
    {
        return s_depositsOnTheWayArray;
    }

    function getPendingWithdrawalRequestIds() external view returns (bytes32[] memory) {
        return s_withdrawalRequestIds;
    }

    function getLiquidityCap() external view returns (uint256) {
        return s_liquidityCap;
    }

    function handleOracleFulfillment(
        bytes32 requestId,
        bytes memory delegateCallResponse,
        bytes memory err
    ) external {
        if (msg.sender != i_clfRouter) {
            revert OnlyRouterCanFulfill(msg.sender);
        }

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IParentPoolCLFCLA.fulfillRequestWrapper.selector,
            requestId,
            delegateCallResponse,
            err
        );

        LibConcero.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
    }

    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        (bool isTriggerNeeded, bytes memory data) = IParentPoolCLFCLAViewDelegate(address(this))
            .checkUpkeepViaDelegate();

        return (isTriggerNeeded, data);
    }

    function checkUpkeepViaDelegate() external returns (bool, bytes memory) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            AutomationCompatibleInterface.checkUpkeep.selector,
            bytes("")
        );

        bytes memory delegateCallResponse = LibConcero.safeDelegateCall(
            address(i_parentPoolCLFCLA),
            delegateCallArgs
        );

        return abi.decode(delegateCallResponse, (bool, bytes));
    }

    function calculateLPTokensToMint(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256) {
        return _calculateLPTokensToMint(childPoolsBalance, amountToDeposit);
    }

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256) {
        return
            IParentPoolCLFCLAViewDelegate(address(this)).calculateWithdrawableAmountViaDelegateCall(
                childPoolsBalance,
                clpAmount
            );
    }

    function calculateWithdrawableAmountViaDelegateCall(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external returns (uint256) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IParentPoolCLFCLA.calculateWithdrawableAmount.selector,
            childPoolsBalance,
            clpAmount
        );

        bytes memory delegateCallResponse = LibConcero.safeDelegateCall(
            address(i_parentPoolCLFCLA),
            delegateCallArgs
        );

        return abi.decode(delegateCallResponse, (uint256));
    }

    function performUpkeep(bytes calldata _performData) external {
        if (msg.sender != i_automationForwarder) {
            revert Unauthorized();
        }

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            AutomationCompatibleInterface.performUpkeep.selector,
            _performData
        );

        LibConcero.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
    }

    /**
     * @notice function for the Concero Orchestrator contract to take loans
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
    ) external payable onlyProxyContext {
        if (msg.sender != i_infraProxy) revert NotConceroInfraProxy();
        if (_receiver == address(0)) revert InvalidAddress();
        //todo: enforce receiver to be i_infraProxy
        if (_token != address(i_USDC)) revert NotUsdcToken();
        IERC20(_token).safeTransfer(_receiver, _amount);
        s_loansInUse += _amount;
    }

    /**
     * @notice Allows a user to initiate the deposit. Currently supports USDC only.
     * @param _usdcAmount amount to be deposited
     */
    function startDeposit(uint256 _usdcAmount) external onlyProxyContext {
        revert("paused");
        if (_usdcAmount < MIN_DEPOSIT) {
            revert DepositAmountBelowMinimum(MIN_DEPOSIT);
        }

        uint256 liquidityCap = s_liquidityCap;

        if (
            _usdcAmount +
                i_USDC.balanceOf(address(this)) -
                s_depositFeeAmount +
                s_loansInUse -
                s_withdrawAmountLocked >
            liquidityCap
        ) {
            revert MaxDepositCapReached(liquidityCap);
        }

        bytes[] memory args = new bytes[](3);
        args[0] = abi.encodePacked(s_getChildPoolsLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(CLFRequestType.startDeposit_getChildPoolsLiquidity);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IParentPoolCLFCLA.sendCLFRequest.selector,
            args
        );
        bytes memory delegateCallResponse = LibConcero.safeDelegateCall(
            address(i_parentPoolCLFCLA),
            delegateCallArgs
        );
        bytes32 clfRequestId = bytes32(delegateCallResponse);
        uint256 _deadline = block.timestamp + DEPOSIT_DEADLINE_SECONDS;

        s_clfRequestTypes[clfRequestId] = CLFRequestType.startDeposit_getChildPoolsLiquidity;
        s_depositRequests[clfRequestId].lpAddress = msg.sender;
        s_depositRequests[clfRequestId].usdcAmountToDeposit = _usdcAmount;
        s_depositRequests[clfRequestId].deadline = _deadline;

        emit DepositInitiated(clfRequestId, msg.sender, _usdcAmount, _deadline);
    }

    /**
     * @notice Completes the deposit process initiated via startDeposit().
     * @notice This function needs to be called within the deadline of DEPOSIT_DEADLINE_SECONDS, set in startDeposit().
     * @param _depositRequestId the ID of the deposit request
     */
    function completeDeposit(bytes32 _depositRequestId) external onlyProxyContext {
        revert("paused");
        DepositRequest storage request = s_depositRequests[_depositRequestId];
        address lpAddress = request.lpAddress;
        uint256 usdcAmount = request.usdcAmountToDeposit;
        uint256 usdcAmountAfterFee = usdcAmount - DEPOSIT_FEE_USDC;
        uint256 childPoolsLiquiditySnapshot = request.childPoolsLiquiditySnapshot;

        if (msg.sender != lpAddress) {
            revert NotAllowedToCompleteDeposit();
        }
        if (block.timestamp > request.deadline) {
            revert DepositDeadlinePassed();
        }
        if (childPoolsLiquiditySnapshot == 0) {
            revert DepositRequestNotReady();
        }

        uint256 lpTokensToMint = _calculateLPTokensToMint(
            childPoolsLiquiditySnapshot,
            usdcAmountAfterFee
        );

        i_USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        i_lpToken.mint(msg.sender, lpTokensToMint);

        _distributeLiquidityToChildPools(usdcAmountAfterFee, ICCIP.CcipTxType.deposit);

        s_depositFeeAmount += DEPOSIT_FEE_USDC;

        emit DepositCompleted(_depositRequestId, msg.sender, usdcAmount, lpTokensToMint);

        delete s_depositRequests[_depositRequestId];
    }

    /*
     * @notice Allows liquidity providers to initiate the withdrawal
     * @notice A cooldown period of WITHDRAW_DEADLINE_SECONDS needs to pass before the withdrawal can be completed.
     * @param _lpAmount the amount of LP tokens to be burnt
     */
    function startWithdrawal(uint256 _lpAmount) external onlyProxyContext {
        revert("paused");
        if (_lpAmount < 1 ether) revert WithdrawAmountBelowMinimum(1 ether);
        if (s_withdrawalIdByLPAddress[msg.sender] != bytes32(0)) {
            revert WithdrawalRequestAlreadyExists();
        }

        bytes[] memory args = new bytes[](2);
        args[0] = abi.encodePacked(s_getChildPoolsLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);

        IERC20(i_lpToken).safeTransferFrom(msg.sender, address(this), _lpAmount);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IParentPoolCLFCLA.sendCLFRequest.selector,
            args
        );
        bytes memory delegateCallResponse = LibConcero.safeDelegateCall(
            address(i_parentPoolCLFCLA),
            delegateCallArgs
        );
        bytes32 clfRequestId = bytes32(delegateCallResponse);

        bytes32 withdrawalId = keccak256(
            abi.encodePacked(msg.sender, _lpAmount, block.number, clfRequestId)
        );

        s_clfRequestTypes[clfRequestId] = CLFRequestType.startWithdrawal_getChildPoolsLiquidity;

        // partially initialise withdrawalRequest struct
        s_withdrawRequests[withdrawalId].lpAddress = msg.sender;
        s_withdrawRequests[withdrawalId].lpAmountToBurn = _lpAmount;

        s_withdrawalIdByCLFRequestId[clfRequestId] = withdrawalId;
        s_withdrawalIdByLPAddress[msg.sender] = withdrawalId;
    }

    /**
     * @notice Function called to finalize the withdraw process.
     * @dev The msg.sender will be used to load the withdraw request data
     * if the request received the total amount requested from other pools,
     * the withdraw will be finalize. If not, it must revert
     */
    //    function completeWithdrawal() external onlyProxyContext {
    //        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];
    //        if (withdrawalId == bytes32(0)) revert WithdrawRequestDoesntExist(withdrawalId);
    //
    //        WithdrawRequest memory withdrawRequest = s_withdrawRequests[withdrawalId];
    //
    //        uint256 amountToWithdraw = withdrawRequest.amountToWithdraw;
    //        uint256 lpAmountToBurn = withdrawRequest.lpAmountToBurn;
    //        uint256 remainingLiquidityFromChildPools = withdrawRequest.remainingLiquidityFromChildPools;
    //
    //        if (amountToWithdraw == 0) revert ActiveRequestNotFulfilledYet();
    //
    //        if (remainingLiquidityFromChildPools > 10) {
    //            revert WithdrawalAmountNotReady(remainingLiquidityFromChildPools);
    //        }
    //
    //        s_withdrawAmountLocked = s_withdrawAmountLocked > amountToWithdraw
    //            ? s_withdrawAmountLocked - amountToWithdraw
    //            : 0;
    //
    //        // uint256 withdrawFees = _calculateWithdrawTransactionsFee(withdraw.amountToWithdraw);
    //        // uint256 withdrawAmountMinusFees = withdraw.amountToWithdraw - _convertToUSDCTokenDecimals(withdrawFees);
    //
    //        delete s_withdrawalIdByLPAddress[msg.sender];
    //        delete s_withdrawRequests[withdrawalId];
    //
    //        i_lpToken.burn(lpAmountToBurn);
    //
    //        i_USDC.safeTransfer(msg.sender, amountToWithdraw);
    //
    //        emit Withdrawn(
    //            withdrawalId,
    //            msg.sender,
    //            address(i_USDC),
    //            amountToWithdraw
    //        );
    //    }

    /**
     * @notice Allows the LP to retry the withdrawal request if the Chainlink Functions failed to execute it
     */
    function retryPerformWithdrawalRequest() external {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IParentPoolCLFCLA.retryPerformWithdrawalRequest.selector
        );

        LibConcero.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
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
        if (s_childPools[_chainSelector] == address(0)) revert InvalidAddress();
        if (s_distributeLiquidityRequestProcessed[_requestId]) {
            revert DistributeLiquidityRequestAlreadyProceeded(_requestId);
        } else {
            s_distributeLiquidityRequestProcessed[_requestId] = true;
        }
        _ccipSend(_chainSelector, _amountToSend, ICCIP.CcipTxType.liquidityRebalancing);
    }

    function withdrawDepositFees() external payable onlyOwner {
        i_USDC.safeTransfer(i_owner, s_depositFeeAmount);
        s_depositFeeAmount = 0;
    }

    /* SETTER FUNCTIONS */
    /**
     * @notice function to manage the Cross-chains Concero contracts
     * @param _chainSelector chain identifications
     * @param _contractAddress address of the Cross-chains Concero contracts
     * @param _isAllowed bool to allow or disallow the contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used in ConceroPool.sol
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
     * @notice Function to set the Cap of the Master pool.
     * @param _newCap The new Cap of the pool
     */
    function setPoolCap(uint256 _newCap) external payable onlyOwner {
        s_liquidityCap = _newCap;
    }

    function setDonHostedSecretsSlotId(uint8 _slotId) external payable onlyOwner {
        s_donHostedSecretsSlotId = _slotId;
    }

    /**
     * @notice Function to set the Don Secrets Version from Chainlink Functions
     * @param _version the version
     * @dev this functions was used inside of ConceroFunctions
     */
    function setDonHostedSecretsVersion(uint64 _version) external payable onlyOwner {
        s_donHostedSecretsVersion = _version;
    }

    /**
     * @notice Function to set the Source JS code for Chainlink Functions
     * @param _hashSum  the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setCollectLiquidityJsCodeHashSum(bytes32 _hashSum) external payable onlyOwner {
        s_collectLiquidityJsCodeHashSum = _hashSum;
    }

    function setRedistributeLiquidityJsCodeHashSum(bytes32 _hashSum) external payable onlyOwner {
        s_distributeLiquidityJsCodeHashSum = _hashSum;
    }

    /**
     * @notice Function to set the Ethers JS code for Chainlink Functions
     * @param _ethersHashSum the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setEthersHashSum(bytes32 _ethersHashSum) external payable onlyOwner {
        s_ethersHashSum = _ethersHashSum;
    }

    function setGetBalanceJsCodeHashSum(bytes32 _hashSum) external payable onlyOwner {
        s_getChildPoolsLiquidityJsCodeHashSum = _hashSum;
    }

    /**
     * @notice function to manage the Cross-chain ConceroPool contracts
     * @param _chainSelector chain identifications
     * @param _pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used on ConceroPool.sol
     */
    function setPools(
        uint64 _chainSelector,
        address _pool,
        bool isRebalancingNeeded
    ) external payable onlyOwner {
        if (s_childPools[_chainSelector] == _pool || _pool == address(0)) {
            revert InvalidAddress();
        }

        s_poolChainSelectors.push(_chainSelector);
        s_childPools[_chainSelector] = _pool;

        if (isRebalancingNeeded) {
            bytes32 distributeLiquidityRequestId = keccak256(
                abi.encodePacked(_pool, _chainSelector, RedistributeLiquidityType.addPool)
            );

            bytes[] memory args = new bytes[](7);
            args[0] = abi.encodePacked(s_distributeLiquidityJsCodeHashSum);
            args[1] = abi.encodePacked(s_ethersHashSum);
            args[2] = abi.encodePacked(CLFRequestType.liquidityRedistribution);
            args[3] = abi.encodePacked(_chainSelector);
            args[4] = abi.encodePacked(distributeLiquidityRequestId);
            args[5] = abi.encodePacked(RedistributeLiquidityType.addPool);
            args[6] = abi.encodePacked(block.chainid);

            bytes memory delegateCallArgs = abi.encodeWithSelector(
                IParentPoolCLFCLA.sendCLFRequest.selector,
                args
            );
            LibConcero.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
        }
    }

    /**
     * @notice Function to remove Cross-chain address disapproving transfers
     * @param _chainSelector the CCIP chainSelector for the specific chain
     */
    function removePools(uint64 _chainSelector) external payable onlyOwner {
        address removedPool;
        for (uint256 i; i < s_poolChainSelectors.length; i++) {
            if (s_poolChainSelectors[i] == _chainSelector) {
                removedPool = s_childPools[_chainSelector];
                s_poolChainSelectors[i] = s_poolChainSelectors[s_poolChainSelectors.length - 1];
                s_poolChainSelectors.pop();
                delete s_childPools[_chainSelector];
            }
        }

        //        bytes32 distributeLiquidityRequestId = keccak256(
        //            abi.encodePacked(
        //                removedPool,
        //                _chainSelector,
        //                RedistributeLiquidityType.removePool,
        //                block.timestamp,
        //                block.number
        //            )
        //        );
        //
        //        bytes[] memory args = new bytes[](6);
        //        args[0] = abi.encodePacked(s_distributeLiquidityJsCodeHashSum);
        //        args[1] = abi.encodePacked(s_ethersHashSum);
        //        args[2] = abi.encodePacked(CLFRequestType.liquidityRedistribution);
        //        args[3] = abi.encodePacked(_chainSelector);
        //        args[4] = abi.encodePacked(distributeLiquidityRequestId);
        //        args[5] = abi.encodePacked(RedistributeLiquidityType.removePool);
        //
        //        bytes memory delegateCallArgs = abi.encodeWithSelector(
        //            IParentPoolCLFCLA.sendCLFRequest.selector,
        //            args
        //        );
        //        LibConcero.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
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
        } else if (ccipTxData.ccipTxType == ICCIP.CcipTxType.withdrawal) {
            bytes32 withdrawalId = abi.decode(ccipTxData.data, (bytes32));

            WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

            if (request.amountToWithdraw == 0) {
                revert WithdrawRequestDoesntExist(withdrawalId);
            }

            request.remainingLiquidityFromChildPools = request.remainingLiquidityFromChildPools >=
                ccipReceivedAmount
                ? request.remainingLiquidityFromChildPools - ccipReceivedAmount
                : 0;

            s_withdrawalsOnTheWayAmount = s_withdrawalsOnTheWayAmount >= ccipReceivedAmount
                ? s_withdrawalsOnTheWayAmount - ccipReceivedAmount
                : 0;

            s_withdrawAmountLocked += ccipReceivedAmount;

            if (request.remainingLiquidityFromChildPools < 10) {
                _completeWithdrawal(withdrawalId);
            }
        }

        // TODO: maybe we can use underlying ccipReceived event?
        emit CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            ccipReceivedToken,
            ccipReceivedAmount
        );
    }

    /**
     * @notice Function to process the withdraw request
     * @param withdrawalId the id of the withdraw request
     */
    function _completeWithdrawal(bytes32 withdrawalId) internal {
        WithdrawRequest storage request = s_withdrawRequests[withdrawalId];
        uint256 amountToWithdraw = request.amountToWithdraw;
        address lpAddress = request.lpAddress;

        i_lpToken.burn(request.lpAmountToBurn);
        i_USDC.safeTransfer(lpAddress, amountToWithdraw);

        s_withdrawAmountLocked = s_withdrawAmountLocked > amountToWithdraw
            ? s_withdrawAmountLocked - amountToWithdraw
            : 0;

        delete s_withdrawalIdByLPAddress[lpAddress];
        delete s_withdrawRequests[withdrawalId];

        emit WithdrawalCompleted(withdrawalId, lpAddress, address(i_USDC), amountToWithdraw);
    }

    /**
     * @notice helper function to distribute liquidity after LP deposits.
     * @param _amountToDistributeUSDC amount of USDC should be distributed to the pools.
     */
    function _distributeLiquidityToChildPools(
        uint256 _amountToDistributeUSDC,
        ICCIP.CcipTxType _ccipTxType
    ) internal {
        uint256 childPoolsCount = s_poolChainSelectors.length;
        uint256 amountToDistributePerPool = ((_amountToDistributeUSDC * PRECISION_HANDLER) /
            (childPoolsCount + 1)) / PRECISION_HANDLER;

        uint64[] memory poolChainSelectors = s_poolChainSelectors;

        for (uint256 i; i < childPoolsCount; ) {
            bytes32 ccipMessageId = _ccipSend(
                poolChainSelectors[i],
                amountToDistributePerPool,
                _ccipTxType
            );

            _addDepositOnTheWay(ccipMessageId, poolChainSelectors[i], amountToDistributePerPool);

            unchecked {
                ++i;
            }
        }
    }

    //TODO: _ccipSend, ccipReceived and other mutual pool functions should be moved to a separate contract
    /**
     * @notice Function to distribute funds automatically right after LP deposits into the pool
     * @dev this function will only be called internally.
     */
    function _ccipSend(
        uint64 _chainSelector,
        uint256 _amount,
        ICCIP.CcipTxType _ccipTxType
    ) internal returns (bytes32) {
        IInfraStorage.SettlementTx[] memory emptyBridgeTxArray;
        ICCIP.CcipTxData memory ccipTxData = ICCIP.CcipTxData({
            ccipTxType: _ccipTxType,
            data: abi.encode(emptyBridgeTxArray)
        });

        address recipient = s_childPools[_chainSelector];
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            recipient,
            address(i_USDC),
            _amount,
            ccipTxData
        );

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(_chainSelector, evm2AnyMessage);

        i_USDC.approve(i_ccipRouter, _amount);
        i_linkToken.approve(i_ccipRouter, ccipFeeAmount);

        return IRouterClient(i_ccipRouter).ccipSend(_chainSelector, evm2AnyMessage);
    }

    function _buildCCIPMessage(
        address _recipient,
        address _token,
        uint256 _amount,
        ICCIP.CcipTxData memory _ccipTxData
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_recipient),
                data: abi.encode(_ccipTxData),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: CCIP_SEND_GAS_LIMIT})
                ),
                feeToken: address(i_linkToken)
            });
    }

    /**
     * @notice Function called by Chainlink Functions fulfillRequest to update deposit information
     * @param _childPoolsTotalBalance The total cross chain balance of child pools
     * @param _amountToDeposit the amount of USDC deposited
     * @dev This function must be called only by an allowed Messenger & must not revert
     * @dev _totalUSDCCrossChainBalance MUST have 10**6 decimals.
     */
    function _calculateLPTokensToMint(
        uint256 _childPoolsTotalBalance,
        uint256 _amountToDeposit
    ) private view returns (uint256) {
        uint256 parentPoolLiquidity = i_USDC.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        //TODO: add withdrawalsOnTheWay

        uint256 totalCrossChainLiquidity = _childPoolsTotalBalance + parentPoolLiquidity;
        uint256 _totalLPSupply = i_lpToken.totalSupply();

        if (_totalLPSupply == 0) {
            return _convertToLPTokenDecimals(_amountToDeposit);
        }

        uint256 crossChainBalanceConverted = _convertToLPTokenDecimals(totalCrossChainLiquidity);
        uint256 amountDepositedConverted = _convertToLPTokenDecimals(_amountToDeposit);

        return
            (((crossChainBalanceConverted + amountDepositedConverted) * _totalLPSupply) /
                crossChainBalanceConverted) - _totalLPSupply;
    }

    function _addDepositOnTheWay(
        bytes32 _ccipMessageId,
        uint64 _chainSelector,
        uint256 _amount
    ) internal {
        uint8 index = s_latestDepositOnTheWayIndex < (MAX_DEPOSITS_ON_THE_WAY_COUNT - 1)
            ? ++s_latestDepositOnTheWayIndex
            : _findLowestDepositOnTheWayUnusedIndex();

        s_depositsOnTheWayArray[index] = DepositOnTheWay({
            ccipMessageId: _ccipMessageId,
            chainSelector: _chainSelector,
            amount: _amount
        });

        s_depositsOnTheWayAmount += _amount;
    }

    function _findLowestDepositOnTheWayUnusedIndex() internal returns (uint8) {
        uint8 index;
        for (uint8 i = 1; i < MAX_DEPOSITS_ON_THE_WAY_COUNT; i++) {
            if (s_depositsOnTheWayArray[i].ccipMessageId == bytes32(0)) {
                index = i;
                s_latestDepositOnTheWayIndex = i;
                break;
            }
        }

        if (index == 0) {
            revert DepositsOnTheWayArrayFull();
        }

        return index;
    }

    /**
     * @notice getter function to calculate Destination fee amount on Source
     * @param amount the amount of tokens to calculate over
     * @return the fee amount
     */
    function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
        return (amount * PRECISION_HANDLER) / LP_FEE_FACTOR / PRECISION_HANDLER;
    }

    // function _calculateDepositTransactionFee(uint256 _amountToDistribute) internal view returns(uint256 _totalUSDCCost){
    //   uint256 numberOfPools = s_poolChainSelectors.length;
    //   uint256 costOfLinkForLiquidityDistribution;
    //   uint256 premiumFee = Orchestrator(i_infraProxy).clfPremiumFees(BASE_CHAIN_SELECTOR);
    //   uint256 lastNativeUSDCRate = Orchestrator(i_infraProxy).s_latestNativeUsdcRate();
    //   uint256 lastLinkUSDCRate = Orchestrator(i_infraProxy).s_latestLinkUsdcRate();
    //   uint256 lastBaseGasPrice = tx.gasprice; //Orchestrator(i_infraProxy).s_lastGasPrices(BASE_CHAIN_SELECTOR);

    //   for(uint256 i; i < numberOfPools; ){
    //     Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), (_amountToDistribute / (numberOfPools+1)), s_childPools[s_poolChainSelectors[i]]);

    //     //Link cost for all transactions
    //     costOfLinkForLiquidityDistribution += IRouterClient(i_ccipRouter).getFee(s_poolChainSelectors[i], evm2AnyMessage);
    //     unchecked {
    //       ++i;
    //     }
    //   }

    //   //_totalUSDCCost
    //   //    Pools.length x Calls to distribute liquidity
    //   //    1x Functions request sent
    //   //    1x Callback Writing to storage
    //   _totalUSDCCost = ((costOfLinkForLiquidityDistribution + premiumFee) * lastLinkUSDCRate) + ((WRITE_FUNCTIONS_COST * lastBaseGasPrice) * lastNativeUSDCRate);
    // }

    // function _calculateWithdrawTransactionsFee(uint256 _amountToReceive) internal view returns(uint256 _totalUSDCCost){
    //   uint256 numberOfPools = s_poolChainSelectors.length;
    //   uint256 premiumFee = Orchestrator(i_infraProxy).clfPremiumFees(BASE_CHAIN_SELECTOR);
    //   uint256 baseLastGasPrice = tx.gasprice; //Orchestrator(i_infraProxy).s_lastGasPrices(BASE_CHAIN_SELECTOR);
    //   uint256 lastNativeUSDCRate = Orchestrator(i_infraProxy).s_latestNativeUsdcRate();
    //   uint256 lastLinkUSDCRate = Orchestrator(i_infraProxy).s_latestLinkUsdcRate();

    //   uint256 costOfLinkForLiquidityWithdraw;
    //   uint256 costOfCCIPSendToPoolExecution;

    //   for(uint256 i; i < numberOfPools; ){
    //     Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), _amountToReceive, address(this));

    //     //Link cost for all transactions
    //     costOfLinkForLiquidityWithdraw += IRouterClient(i_ccipRouter).getFee(BASE_CHAIN_SELECTOR, evm2AnyMessage); //here the chainSelector must be Base's?
    //     //USDC costs for all writing from the above transactions
    //     costOfCCIPSendToPoolExecution += Orchestrator(i_infraProxy).s_lastGasPrices(s_poolChainSelectors[i]) * WRITE_FUNCTIONS_COST;
    //     unchecked {
    //       ++i;
    //     }
    //   }

    //   // _totalUSDCCost ==
    //   //    2x Functions Calls - Link Cost
    //   //    Pools.length x Calls - Link Cost
    //   //    Base's gas Cost of callback
    //   //    Pools.length x Calls to ccipSendToPool Child Pool function
    //   //  Automation Costs?
    //   //    SLOAD - 2100
    //   //    ++i - 5
    //   //    Comparing = 3
    //   //    STORE - 5_000
    //   //    Array Reduction - 5_000
    //   //    gasOverhead - 80_000
    //   //    Nodes Premium - 50%
    //   uint256 arrayLength = i_automation.getPendingWithdrawRequestsLength();

    //   uint256 automationCost = (((CLA_PERFORMUPKEEP_ITERATION_GAS_COSTS * arrayLength) + ARRAY_MANIPULATION + CLA_OVERHEAD) * NODE_PREMIUM) / 100;
    //   _totalUSDCCost = (((premiumFee * 2) + costOfLinkForLiquidityWithdraw + automationCost) * lastLinkUSDCRate) + ((WRITE_FUNCTIONS_COST * baseLastGasPrice) * lastNativeUSDCRate) + costOfCCIPSendToPoolExecution;
    // }
}

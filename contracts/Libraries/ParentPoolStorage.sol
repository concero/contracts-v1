// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IParentPool} from "../Interfaces/IParentPool.sol";

contract ParentPoolStorage {
    /* STATE VARIABLES */

    ///@notice variable to store the max value that can be deposited on this pool
    uint256 public s_liquidityCap;
    ///@notice variable to store the amount that will be temporary used by Chainlink Functions
    uint256 public s_loansInUse;
    ///@notice variable to store the Chainlink Function DON Slot ID
    //TODO: these two need to be moved to immutable and deprecated.
    uint8 internal s_donHostedSecretsSlotId;
    ///@notice variable to store the Chainlink Function DON Secret Version
    uint64 internal s_donHostedSecretsVersion;
    ///@notice variable to store the Chainlink Function Source Hashsum
    bytes32 internal s_getChildPoolsLiquidityJsCodeHashSum;
    ///@notice variable to store Ethers Hashsum
    bytes32 internal s_ethersHashSum;
    ///@notice variable to store not processed amounts deposited by LPs
    uint256 public s_depositsOnTheWayAmount;

    uint8 internal s_latestDepositOnTheWayIndex;

    uint256 internal s_depositFeeAmount;

    ///@notice variable to store the amount requested in withdraws, incremented at startWithdrawal, decremented at completewithdrawal
    uint256 public s_withdrawAmountLocked;
    //incremented when ccipSend is called on child pools by CLA, decremented with each ccipReceive
    uint256 internal s_withdrawalsOnTheWayAmount;
    ///@notice gap to reserve storage in the contract for future variable additions
    uint256[50] private __gap;

    /* MAPPINGS & ARRAYS */
    ///@notice array of Pools to receive Liquidity through `ccipSend` function
    uint64[] internal s_poolChainSelectors;
    IParentPool.DepositOnTheWay_DEPRECATED[] internal s_depositsOnTheWayArray_DEPRECATED;

    ///@notice Mapping to keep track of valid pools to transfer in case of liquidation or rebalance
    mapping(uint64 chainSelector => address pool) public s_childPools;

    ///@notice Mapping to keep track of allowed pool senders
    mapping(uint64 chainSelector => mapping(address poolAddress => bool))
        public s_isSenderContractAllowed;

    ///@notice Mapping to keep track of Liquidity Providers withdraw requests
    mapping(bytes32 => bool) public s_distributeLiquidityRequestProcessed;

    mapping(bytes32 clfReqId => IParentPool.CLFRequestType) public s_clfRequestTypes;

    mapping(bytes32 clfReqId => IParentPool.DepositRequest) public s_depositRequests;

    mapping(address lpAddress => bytes32 withdrawalId) public s_withdrawalIdByLPAddress;

    mapping(bytes32 clfReqId => bytes32 withdrawalId) public s_withdrawalIdByCLFRequestId;

    mapping(bytes32 withdrawalId => IParentPool.WithdrawRequest) public s_withdrawRequests;

    /* NEW STORAGE SLOTS */

    IParentPool.DepositOnTheWay[150] internal s_depositsOnTheWayArray;

    //TODO: these two need to be moved to immutable and deprecated.
    bytes32 internal s_collectLiquidityJsCodeHashSum;
    bytes32 internal s_distributeLiquidityJsCodeHashSum;

    ///@notice array to store the withdraw requests of users
    bytes32[] public s_withdrawalRequestIds;

    ///@notice Mapping to keep track of Chainlink Functions requests
    mapping(bytes32 withdrawalId => bool isTriggered) public s_withdrawTriggered;
}

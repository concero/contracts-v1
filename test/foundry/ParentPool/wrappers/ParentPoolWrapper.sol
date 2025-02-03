// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ParentPool} from "contracts/ParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

interface IParentPoolWrapper is IParentPool {
    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ParentPool.DepositRequest memory);

    function getRequestType(bytes32 requestId) external view returns (ParentPool.CLFRequestType);

    function isMessenger(address _messenger) external view returns (bool);

    function getDepositsOnTheWayAmount() external view returns (uint256);
}

contract ParentPoolWrapper is ParentPool {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
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
    )
        ParentPool(
            _parentPoolProxy,
            _parentPoolCLFCLA,
            _automationForwarder,
            _link,
            _ccipRouter,
            _usdc,
            _lpToken,
            _infraProxy,
            _clfRouter,
            _owner,
            _messengers
        )
    {}

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ParentPool.DepositRequest memory) {
        return s_depositRequests[requestId];
    }

    function getRequestType(bytes32 requestId) external view returns (ParentPool.CLFRequestType) {
        return s_clfRequestTypes[requestId];
    }

    function isMessenger(address _messenger) public view returns (bool) {
        return _isMessenger(_messenger);
    }

    function getDepositsOnTheWayAmount() external view returns (uint256) {
        return s_depositsOnTheWayAmount;
    }

    function addDepositOnTheWay(bytes32 requestId, uint64 childPoolIndex, uint256 amount) external {
        _addDepositOnTheWay(requestId, childPoolIndex, amount);
    }

    function getWithdrawalRequest(
        bytes32 withdrawalId
    ) external view returns (IParentPool.WithdrawRequest memory) {
        return s_withdrawRequests[withdrawalId];
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/
    /// @dev getter for returning withdraw request params
    function getWithdrawRequestParams(
        bytes32 _withdrawalRequestId
    ) external view returns (address lpAddress, uint256 lpAmountToBurn, uint256 amountToWithdraw) {
        WithdrawRequest memory request = s_withdrawRequests[_withdrawalRequestId];
        lpAddress = request.lpAddress;
        lpAmountToBurn = request.lpAmountToBurn;
        amountToWithdraw = request.amountToWithdraw;
    }
}

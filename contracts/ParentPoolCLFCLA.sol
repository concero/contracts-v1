// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IParentPoolCLFCLA} from "./Interfaces/IParentPoolCLFCLA.sol";
import {IParentPool} from "./Interfaces/IParentPool.sol";
import {ParentPoolCommon} from "./ParentPoolCommon.sol";
import {ParentPoolStorage} from "./Libraries/ParentPoolStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error Unauthorized();
error WithdrawalAlreadyTriggered(bytes32 id);
error WithdrawalRequestDoesntExist(bytes32 id);
error WithdrawalRequestNotReady(bytes32 id);
error WithdrawalAlreadyPerformed(bytes32 id);
contract ParentPoolCLFCLA is
    IParentPoolCLFCLA,
    FunctionsClient,
    AutomationCompatible,
    ParentPoolCommon,
    ParentPoolStorage
{
    using FunctionsRequest for FunctionsRequest.Request;
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint256 internal constant CCIP_ESTIMATED_TIME_TO_COMPLETE = 30 minutes;
    uint32 internal constant CLF_CALLBACK_GAS_LIMIT = 2_000_000;
    string internal constant JS_CODE =
        "try{const [b,o,f]=bytesArgs;const m='https://raw.githubusercontent.com/';const u=m+'ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';const q=m+'concero/contracts-v1/'+'release'+`/tasks/CLFScripts/dist/pool/${f==='0x02' ? 'withdrawalLiquidityCollection':f==='0x03' ? 'redistributePoolsLiquidity':'getChildPoolsLiquidity'}.min.js`;const [t,p]=await Promise.all([fetch(u),fetch(q)]);const [e,c]=await Promise.all([t.text(),p.text()]);const g=async s=>{return('0x'+Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(v=>('0'+v.toString(16)).slice(-2).toLowerCase()).join(''));};const r=await g(c);const x=await g(e);if(r===b.toLowerCase()&& x===o.toLowerCase()){const ethers=new Function(e+';return ethers;')();return await eval(c);}throw new Error(`${r}!=${b}||${x}!=${o}`);}catch(e){throw new Error(e.message.slice(0,255));}";

    /* IMMUTABLE VARIABLES */
    bytes32 private immutable i_clfDonId;
    uint64 private immutable i_clfSubId;

    /* EVENTS */
    event CLFRequestError(
        bytes32 indexed requestId,
        IParentPool.CLFRequestType requestType,
        bytes err
    );
    event RetryWithdrawalPerformed(bytes32 id);
    event WithdrawUpkeepPerformed(bytes32 id);
    event WithdrawRequestUpdated(bytes32 id);
    event PendingWithdrawRequestAdded(bytes32 id);

    constructor(
        address parentPoolProxy,
        address lpToken,
        address USDC,
        address clfRouter,
        uint64 clfSubId,
        bytes32 clfDonId,
        address[3] memory messengers
    ) ParentPoolCommon(parentPoolProxy, lpToken, USDC, messengers) FunctionsClient(clfRouter) {
        i_clfSubId = clfSubId;
        i_clfDonId = clfDonId;
    }

    /**
     * @notice Chainlink Functions fallback function
     * @param requestId the ID of the request sent
     * @param response the response of the request sent
     * @param err the error of the request sent
     * @dev response & err will never be empty or populated at same time.
     */
    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        IParentPool.CLFRequestType requestType = s_clfRequestTypes[requestId];

        if (err.length > 0) {
            if (requestType == IParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity) {
                delete s_depositRequests[requestId];
            } else if (
                requestType == IParentPool.CLFRequestType.startWithdrawal_getChildPoolsLiquidity
            ) {
                bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
                address lpAddress = s_withdrawRequests[withdrawalId].lpAddress;
                uint256 lpAmountToBurn = s_withdrawRequests[withdrawalId].lpAmountToBurn;

                IERC20(i_lpToken).safeTransfer(lpAddress, lpAmountToBurn);

                delete s_withdrawRequests[withdrawalId];
                delete s_withdrawalIdByLPAddress[lpAddress];
                delete s_withdrawalIdByCLFRequestId[requestId];
            }

            emit CLFRequestError(requestId, requestType, err);
        } else {
            if (requestType == IParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity) {
                _handleStartDepositCLFFulfill(requestId, response);
            } else if (
                requestType == IParentPool.CLFRequestType.startWithdrawal_getChildPoolsLiquidity
            ) {
                _handleStartWithdrawalCLFFulfill(requestId, response);
                delete s_withdrawalIdByCLFRequestId[requestId];
            } else if (
                requestType == IParentPool.CLFRequestType.withdrawal_requestLiquidityCollection
            ) {
                _handleAutomationCLFFulfill(requestId);
            }
        }

        delete s_clfRequestTypes[requestId];
    }

    function sendCLFRequest(bytes[] memory args) external onlyProxyContext returns (bytes32) {
        return _sendRequest(args);
    }

    /* AUTOMATION EXTERNAL */

    /**
     * @notice Chainlink Automation Function to check for requests with fulfilled conditions
     * We don't use the calldata
     * @return _upkeepNeeded it will return true, if the time condition is reached
     * @return _performData the payload we need to send through performUpkeep to Chainlink functions.
     * @dev this function must only be simulated offchain by Chainlink Automation nodes
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override cannotExecute returns (bool, bytes memory) {
        uint256 s_withdrawalRequestIdsLength = s_withdrawalRequestIds.length;
        for (uint256 i; i < s_withdrawalRequestIdsLength; ++i) {
            bytes32 withdrawalId = s_withdrawalRequestIds[i];

            if (s_withdrawRequests[withdrawalId].amountToWithdraw == 0) {
                continue;
            }

            if (
                !s_withdrawTriggered[withdrawalId] &&
                block.timestamp > s_withdrawRequests[withdrawalId].triggeredAtTimestamp
            ) {
                bytes memory _performData = abi.encode(withdrawalId);
                return (true, _performData);
            }
        }
        return (false, "");
    }

    /**
     * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
     * @param _performData the performData encoded in checkUpkeep function
     * @dev this function must be called only by the Chainlink Forwarder unique address
     */
    function performUpkeep(bytes calldata _performData) external override onlyProxyContext {
        bytes32 withdrawalId = abi.decode(_performData, (bytes32));

        if (withdrawalId == bytes32(0)) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

        if (block.timestamp < s_withdrawRequests[withdrawalId].triggeredAtTimestamp) {
            revert WithdrawalRequestNotReady(withdrawalId);
        }

        if (s_withdrawTriggered[withdrawalId]) {
            revert WithdrawalAlreadyTriggered(withdrawalId);
        } else {
            s_withdrawTriggered[withdrawalId] = true;
        }

        uint256 liquidityRequestedFromEachPool = s_withdrawRequests[withdrawalId]
            .liquidityRequestedFromEachPool;
        if (liquidityRequestedFromEachPool == 0) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

        bytes32 reqId = _sendLiquidityCollectionRequest(
            withdrawalId,
            liquidityRequestedFromEachPool
        );

        s_clfRequestTypes[reqId] = IParentPool.CLFRequestType.withdrawal_requestLiquidityCollection;
        _addWithdrawalOnTheWayAmountById(withdrawalId);
        emit WithdrawUpkeepPerformed(reqId);
    }

    function retryPerformWithdrawalRequest() external onlyProxyContext {
        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];

        if (msg.sender != s_withdrawRequests[withdrawalId].lpAddress) {
            revert Unauthorized();
        }

        uint256 liquidityRequestedFromEachPool = s_withdrawRequests[withdrawalId]
            .liquidityRequestedFromEachPool;
        if (liquidityRequestedFromEachPool == 0) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

        if (s_withdrawRequests[withdrawalId].remainingLiquidityFromChildPools < 10) {
            revert WithdrawalAlreadyPerformed(withdrawalId);
        }

        if (
            block.timestamp <
            s_withdrawRequests[withdrawalId].triggeredAtTimestamp + CCIP_ESTIMATED_TIME_TO_COMPLETE
        ) {
            revert WithdrawalRequestNotReady(withdrawalId);
        }

        bytes32 reqId = _sendLiquidityCollectionRequest(
            withdrawalId,
            liquidityRequestedFromEachPool
        );

        emit RetryWithdrawalPerformed(reqId);
    }

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256) {
        return _calculateWithdrawableAmount(childPoolsBalance, clpAmount, i_lpToken.totalSupply());
    }

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external onlyProxyContext {
        fulfillRequest(requestId, response, err);
    }

    /* INTERNAL FUNCTIONS */
    function _handleStartDepositCLFFulfill(bytes32 requestId, bytes memory response) internal {
        IParentPool.DepositRequest storage request = s_depositRequests[requestId];
        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        request.childPoolsLiquiditySnapshot = childPoolsLiquidity;

        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    function _handleStartWithdrawalCLFFulfill(bytes32 requestId, bytes memory response) internal {
        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
        IParentPool.WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

        _updateWithdrawalRequest(request, withdrawalId, childPoolsLiquidity);
        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    /// @dev taken from the ConceroAutomation::fulfillRequest logic
    function _handleAutomationCLFFulfill(bytes32 _requestId) internal {
        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[_requestId];

        for (uint256 i; i < s_withdrawalRequestIds.length; ++i) {
            if (s_withdrawalRequestIds[i] == withdrawalId) {
                s_withdrawalRequestIds[i] = s_withdrawalRequestIds[
                    s_withdrawalRequestIds.length - 1
                ];
                s_withdrawalRequestIds.pop();
            }
        }
    }

    function _decodeCLFResponse(
        bytes memory response
    ) internal pure returns (uint256, bytes1[] memory) {
        uint256 totalBalance;
        assembly {
            totalBalance := mload(add(response, 32))
        }

        if (response.length == 32) {
            return (totalBalance, new bytes1[](0));
        } else {
            bytes1[] memory depositsOnTheWayIdsToDelete = new bytes1[](response.length - 32);
            for (uint256 i = 32; i < response.length; i++) {
                depositsOnTheWayIdsToDelete[i - 32] = response[i];
            }

            return (totalBalance, depositsOnTheWayIdsToDelete);
        }
    }

    function _deleteDepositsOnTheWayByIndexes(
        bytes1[] memory _depositsOnTheWayIndexesToDelete
    ) internal {
        uint256 depositsOnTheWayIndexesToDeleteLength = _depositsOnTheWayIndexesToDelete.length;

        if (depositsOnTheWayIndexesToDeleteLength == 0) {
            return;
        }

        uint256 s_depositsOnTheWayArrayLength = s_depositsOnTheWayArray.length;

        for (uint256 i; i < depositsOnTheWayIndexesToDeleteLength; i++) {
            uint8 indexToDelete = uint8(_depositsOnTheWayIndexesToDelete[i]);

            if (indexToDelete >= s_depositsOnTheWayArrayLength) {
                continue;
            }

            s_depositsOnTheWayAmount -= s_depositsOnTheWayArray[indexToDelete].amount;
            delete s_depositsOnTheWayArray[indexToDelete];
        }
    }

    /**
     * @notice Function to update cross-chain rewards which will be paid to liquidity providers in the end of
     * withdraw period.
     * @param _withdrawalRequest - pointer to the WithdrawRequest struct
     * @param _childPoolsLiquidity The total liquidity of all child pools
     * @dev This function must be called only by an allowed Messenger & must not revert
     * @dev _totalUSDCCrossChainBalance MUST have 10**6 decimals.
     */
    function _updateWithdrawalRequest(
        IParentPool.WithdrawRequest storage _withdrawalRequest,
        bytes32 _withdrawalId,
        uint256 _childPoolsLiquidity
    ) private {
        uint256 lpToBurn = _withdrawalRequest.lpAmountToBurn;
        uint256 childPoolsCount = s_poolChainSelectors.length;

        uint256 amountToWithdrawWithUsdcDecimals = _calculateWithdrawableAmount(
            _childPoolsLiquidity,
            lpToBurn,
            i_lpToken.totalSupply()
        );
        uint256 withdrawalPortionPerPool = amountToWithdrawWithUsdcDecimals / (childPoolsCount + 1);

        _withdrawalRequest.amountToWithdraw = amountToWithdrawWithUsdcDecimals;
        _withdrawalRequest.liquidityRequestedFromEachPool = withdrawalPortionPerPool;
        _withdrawalRequest.remainingLiquidityFromChildPools =
            amountToWithdrawWithUsdcDecimals -
            withdrawalPortionPerPool;
        _withdrawalRequest.triggeredAtTimestamp = block.timestamp + WITHDRAWAL_COOLDOWN_SECONDS;

        s_withdrawalRequestIds.push(_withdrawalId);
        emit WithdrawalRequestInitiated(
            _withdrawalId,
            msg.sender,
            block.timestamp + WITHDRAWAL_COOLDOWN_SECONDS
        );
    }

    /**
     * @notice Function to send a Request to Chainlink Functions
     * @param _args the arguments for the request as bytes array
     */
    function _sendRequest(bytes[] memory _args) internal returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(JS_CODE);
        req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
        req.setBytesArgs(_args);

        return _sendRequest(req.encodeCBOR(), i_clfSubId, CLF_CALLBACK_GAS_LIMIT, i_clfDonId);
    }

    function _addWithdrawalOnTheWayAmountById(bytes32 _withdrawalId) internal {
        uint256 awaitedChildPoolsWithdrawalAmount = s_withdrawRequests[_withdrawalId]
            .amountToWithdraw - s_withdrawRequests[_withdrawalId].liquidityRequestedFromEachPool;

        if (awaitedChildPoolsWithdrawalAmount == 0) {
            revert WithdrawalRequestDoesntExist(_withdrawalId);
        }

        s_withdrawalsOnTheWayAmount += awaitedChildPoolsWithdrawalAmount;
    }

    function _calculateWithdrawableAmount(
        uint256 _childPoolsBalance,
        uint256 _clpAmount,
        uint256 _lpSupply
    ) internal view returns (uint256) {
        uint256 parentPoolLiquidity = i_USDC.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        uint256 totalCrossChainLiquidity = _childPoolsBalance + parentPoolLiquidity;

        //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
        uint256 amountUsdcToWithdraw = (((_convertToLPTokenDecimals(totalCrossChainLiquidity) *
            _clpAmount) * PRECISION_HANDLER) / _lpSupply) / PRECISION_HANDLER;

        return _convertToUSDCTokenDecimals(amountUsdcToWithdraw);
    }

    function _sendLiquidityCollectionRequest(
        bytes32 withdrawalId,
        uint256 liquidityRequestedFromEachPool
    ) internal returns (bytes32) {
        bytes[] memory args = new bytes[](5);
        args[0] = abi.encodePacked(s_collectLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(
            IParentPool.CLFRequestType.withdrawal_requestLiquidityCollection
        );
        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
        args[4] = abi.encodePacked(withdrawalId);

        bytes32 reqId = _sendRequest(args);
        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;
        return reqId;
    }
}

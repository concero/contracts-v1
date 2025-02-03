// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";

contract InfraOrchestratorWrapper is InfraOrchestrator {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _concero,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    )
        InfraOrchestrator(
            _functionsRouter,
            _dexSwap,
            _concero,
            _pool,
            _proxy,
            _chainIndex,
            _messengers
        )
    {}

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setLastCCIPFeeInLink(uint64 _dstChainSelector, uint256 _lastFeeInLink) external {
        s_lastCCIPFeeInLink[_dstChainSelector] = _lastFeeInLink;
    }

    function setLastGasPriceByChainSelector(uint64 _chainSelector, uint256 _lastGasPrice) external {
        s_lastGasPrices[_chainSelector] = _lastGasPrice;
    }

    function setLatestNativeUsdcRate(uint256 _latestRate) external {
        s_latestNativeUsdcRate = _latestRate;
    }

    function setLatestLinkUsdcRate(uint256 _latestRate) external {
        s_latestLinkUsdcRate = _latestRate;
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getLastCCIPFeeInLink(uint64 _dstChainSelector) external view returns (uint256) {
        return s_lastCCIPFeeInLink[_dstChainSelector];
    }

    function getBridgeTxIdsPerChain(
        uint64 _dstChainSelector
    ) external view returns (bytes32[] memory) {
        return s_pendingSettlementIdsByDstChain[_dstChainSelector];
    }

    function getFunctionsFeeInUsdcDelegateCall(
        uint64 _dstChainSelector
    ) external returns (uint256) {
        (bool success, bytes memory returnData) = i_conceroBridge.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("getFunctionsFeeInUsdc(uint64)")),
                _dstChainSelector
            )
        );
        require(success, "getFunctionsFeeInUsdc delegate call failed");
        uint256 functionsFeeInUsdc = abi.decode(returnData, (uint256));
        return functionsFeeInUsdc;
    }

    function getCcipFeeInUsdcDelegateCall(uint64 _dstChainSelector) external returns (uint256) {
        (bool success, bytes memory returnData) = i_conceroBridge.delegatecall(
            abi.encodeWithSignature("getCCIPFeeInUsdc(uint64)", _dstChainSelector)
        );
        require(success, "getCCIPFeeInUsdc delegate call failed");
        uint256 ccipFeeInUsdc = abi.decode(returnData, (uint256));
        return ccipFeeInUsdc;
    }

    function getSrcTotalFeeInUSDCDelegateCall(
        uint64 _dstChainSelector,
        uint256 _amount
    ) external returns (uint256) {
        (bool success, bytes memory returnData) = i_conceroBridge.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("getSrcTotalFeeInUSDC(uint64,uint256)")),
                _dstChainSelector,
                _amount
            )
        );
        require(success, "getSrcTotalFeeInUSDC delegate call failed");
        uint256 srcTotalFeeInUsdc = abi.decode(returnData, (uint256));
        return srcTotalFeeInUsdc;
    }

    // function calculateIntegratorFee(
    //     uint256 integratorFeePercent,
    //     uint256 amount
    // ) external returns (uint256) {
    //     return _calculateIntegratorFeeAmount(integratorFeePercent, amount);
    // }

    function getCollectedIntegratorFeeByToken(
        address integrator,
        address token
    ) external returns (uint256) {
        return s_integratorFeesAmountByToken[integrator][token];
    }

    function getTotalIntegratorFeeAmountByToken(address token) external returns (uint256) {
        return s_totalIntegratorFeesAmountByToken[token];
    }

    function swapDataToBytes(
        IDexSwap.SwapData[] memory _swapData
    ) external pure returns (bytes memory) {
        if (_swapData.length == 0) {
            return new bytes(1);
        } else {
            return abi.encode(_swapData);
        }
    }

    function getPendingSettlementIdsByChain(
        uint64 dstChainSelector
    ) external returns (bytes32[] memory) {
        return s_pendingSettlementIdsByDstChain[dstChainSelector];
    }

    function getPendingSettlementTxById(
        bytes32 conceroId
    ) external returns (IInfraStorage.SettlementTx memory) {
        return s_pendingSettlementTxsById[conceroId];
    }

    function getPendingSettlementTxAmountByDstChain(
        uint64 dstChainSelector
    ) external returns (uint256) {
        return s_pendingSettlementTxAmountByDstChain[dstChainSelector];
    }
}

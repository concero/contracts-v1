// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {LibConcero} from "contracts/Libraries/LibConcero.sol";

contract InfraOrchestratorMock is InfraOrchestrator {
    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _conceroBridge,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    )
        InfraOrchestrator(
            _functionsRouter,
            _dexSwap,
            _conceroBridge,
            _pool,
            _proxy,
            _chainIndex,
            _messengers
        )
    {}

    function setLatestLinkUsdcRate(uint256 rate) public {
        s_latestLinkUsdcRate = rate;
    }

    function setLatestNativeUsdcRate(uint256 rate) public {
        s_latestNativeUsdcRate = rate;
    }

    function setLatestLinkNativeRate(uint256 rate) public {
        s_latestLinkNativeRate = rate;
    }

    function setLastGasPrices(uint64 chainSelector, uint256 gasPrice) public {
        s_lastGasPrices[chainSelector] = gasPrice;
    }

    function setLastCCIPFeeInLink(uint64 dstChainSelector, uint256 lastFeeInLink) public {
        s_lastCCIPFeeInLink[dstChainSelector] = lastFeeInLink;
    }

    function getFunctionsFeeInUsdc(uint64 dstChainSelector) public returns (uint256) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ConceroBridge.getFunctionsFeeInUsdc.selector,
            dstChainSelector
        );
        bytes memory res = LibConcero.safeDelegateCall(address(i_conceroBridge), delegateCallArgs);
        return abi.decode(res, (uint256));
    }
}

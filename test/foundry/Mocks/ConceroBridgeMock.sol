// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ConceroBridge} from "contracts/ConceroBridge.sol";

contract ConceroBridgeMock is ConceroBridge {
    constructor(
        FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    )
        ConceroBridge(
            _variables,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            _dexSwap,
            _pool,
            _proxy,
            _messengers
        )
    {}

    /* SETTERS */

    function setClfPremiumFees(uint64 chainSelector, uint256 feeAmount) public {
        clfPremiumFees[chainSelector] = feeAmount;
    }

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

    /* GETTERS */

    function getClfPremiumFees(uint64 chainSelector) public view returns (uint256) {
        return clfPremiumFees[chainSelector];
    }

    function getLatestLinkUsdcRate() public view returns (uint256) {
        return s_latestLinkUsdcRate;
    }

    function getLatestNativeUsdcRate() public view returns (uint256) {
        return s_latestNativeUsdcRate;
    }

    function getLatestLinkNativeRate() public view returns (uint256) {
        return s_latestLinkNativeRate;
    }

    function getLastGasPrices(uint64 chainSelector) public view returns (uint256) {
        return s_lastGasPrices[chainSelector];
    }

    function getLastCCIPFeeInLink(uint64 dstChainSelector) public view returns (uint256) {
        return s_lastCCIPFeeInLink[dstChainSelector];
    }
}

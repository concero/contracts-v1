// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {LPToken} from "./LPToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error NotParentPoolProxy(address sender);
error NotMessenger();

contract ParentPoolCommon {
    /* CONSTANT VARIABLES */
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant LP_TOKEN_DECIMALS = 1 ether;
    uint256 internal constant PRECISION_HANDLER = 1e10;
    uint8 internal constant MAX_DEPOSITS_ON_THE_WAY_COUNT = 150;
    uint256 internal constant WITHDRAWAL_COOLDOWN_SECONDS = 597_600;

    /* IMMUTABLE VARIABLES */
    address internal immutable i_parentPoolProxy;
    LPToken public immutable i_lpToken;
    IERC20 internal immutable i_USDC;
    address internal immutable i_msgr0;
    address internal immutable i_msgr1;
    address internal immutable i_msgr2;

    /**
     * @notice modifier to ensure if the function is being executed in the proxy context.
     */
    modifier onlyProxyContext() {
        if (address(this) != i_parentPoolProxy) {
            revert NotParentPoolProxy(address(this));
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

    constructor(address parentPool, address lpToken, address USDC, address[3] memory messengers) {
        i_parentPoolProxy = parentPool;
        i_lpToken = LPToken(lpToken);
        i_msgr0 = messengers[0];
        i_msgr1 = messengers[1];
        i_msgr2 = messengers[2];
        i_USDC = IERC20(USDC);
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice Function to check if a caller address is an allowed messenger
     * @param _messenger the address of the caller
     */
    function _isMessenger(address _messenger) internal view returns (bool) {
        return (_messenger == i_msgr0 || _messenger == i_msgr1 || _messenger == i_msgr2);
    }

    /**
     * @notice Internal function to convert USDC Decimals to LP Decimals
     * @param _usdcAmount the amount of USDC
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToLPTokenDecimals(uint256 _usdcAmount) internal pure returns (uint256) {
        return (_usdcAmount * LP_TOKEN_DECIMALS) / USDC_DECIMALS;
    }

    /**
     * @notice Internal function to convert LP Decimals to USDC Decimals
     * @param _lpAmount the amount of LP
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToUSDCTokenDecimals(uint256 _lpAmount) internal pure returns (uint256) {
        return (_lpAmount * USDC_DECIMALS) / LP_TOKEN_DECIMALS;
    }
}

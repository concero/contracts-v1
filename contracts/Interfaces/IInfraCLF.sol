// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IInfraStorage} from "./IInfraStorage.sol";

interface IInfraCLF is IInfraStorage {
    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    function addUnconfirmedTX(
        bytes32 conceroMessageId,
        uint64 srcChainSelector,
        bytes32 txDataHash
    ) external;
}

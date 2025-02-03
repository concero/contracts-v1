// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface ICCIP {
    ///@notice CCIP transaction types
    enum CcipTxType {
        deposit,
        batchedSettlement,
        withdrawal,
        liquidityRebalancing
    }

    ///@notice CCIP transaction data ie infraType with txIds, recipients, amounts
    struct CcipTxData {
        CcipTxType ccipTxType;
        bytes data;
    }
}

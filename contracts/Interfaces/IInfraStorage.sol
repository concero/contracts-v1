// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IInfraStorage {
    ///@notice Chainlink Functions Request Type
    enum RequestType {
        addUnconfirmedTxDst,
        checkTxSrc
    }

    ///@notice CCIP Compatible Tokens
    //REMOVE IN PRODUCTION : bnm
    enum CCIPToken {
        bnm,
        usdc
    }

    ///@notice Operational Chains
    enum Chain {
        arb,
        base,
        opt,
        pol,
        avax,
        eth
    }

    ///@notice Function Request
    struct Request {
        RequestType requestType;
        bool isPending;
        bytes32 conceroMessageId;
    }

    struct BridgeData {
        uint64 dstChainSelector;
        address receiver;
        uint256 amount;
    }

    ///@notice `ccipSend` to distribute liquidity
    struct Pools {
        uint64 chainSelector;
        address poolAddress;
    }

    struct Transaction {
        bytes32 txDataHash;
        address sender_DEPRECATED;
        address recipient_DEPRECATED;
        uint256 amount_DEPRECATED;
        CCIPToken token_DEPRECATED;
        uint64 srcChainSelector_DEPRECATED;
        bool isConfirmed;
        bytes dstSwapData_DEPRECATED;
    }

    ///@notice Chainlink Functions Variables
    struct FunctionsVariables {
        uint64 subscriptionId;
        bytes32 donId;
        address functionsRouter;
    }

    struct SettlementTx {
        uint256 amount;
        address recipient;
    }

    struct WithdrawalTx {
        bytes32 withdrawalId;
    }
}

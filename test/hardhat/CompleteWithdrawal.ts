import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { Address, createPublicClient, createWalletClient, PrivateKeyAccount } from "viem";
import { PublicClient } from "viem/clients/createPublicClient";
import { approve } from "./utils/approve";
import { chainsMap } from "./utils/chainsMap";

const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
const senderAddress = process.env.TESTS_WALLET_ADDRESS as Address;
const lpAmount = "100000000000000000";
const lpTokenAddress = process.env.LPTOKEN_BASE_SEPOLIA as Address;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("complete withdraw usdc from pool\n", async () => {
  const { abi: ParentPoolAbi } = await import("../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  let srcPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
  });

  let viemAccount: PrivateKeyAccount = privateKeyToAccount(
    ("0x" + process.env.TESTS_WALLET_PRIVATE_KEY) as `0x${string}`,
  );
  let nonce: BigInt;
  let walletClient: WalletClient<HttpTransport, Chain, Account, RpcSchema> = createWalletClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
    account: viemAccount,
  });

  before(async () => {
    nonce = BigInt(
      await srcPublicClient.getTransactionCount({
        address: viemAccount.address,
      }),
    );
  });

  const callApprovals = async () => {
    await approve(lpTokenAddress, poolAddress, BigInt(lpAmount), walletClient, srcPublicClient);
  };

  it("should complete withdraw usdc from pool", async () => {
    try {
      await callApprovals();

      const transactionHash = await walletClient.writeContract({
        abi: ParentPoolAbi,
        functionName: "completeWithdrawal",
        address: poolAddress as Address,
        gas: 3_000_000n,
      });

      const { status } = await srcPublicClient.waitForTransactionReceipt({ hash: transactionHash });

      console.log("transactionHash: ", transactionHash);
      console.log("status: ", status, "\n");
    } catch (error) {
      console.error("Error: ", error);
    }
  }).timeout(0);
});

import { task } from "hardhat/config";
import { conceroChains, networkEnvKeys, ProxyEnum } from "../../../constants";
import { getClients, getEnvAddress, getEnvVar } from "../../../utils";
import { Address, erc20Abi, parseAbi } from "viem";

async function getPoolsBalanceAndLoansInUse() {
  const childPoolInfo = {};

  for (const chain of [...conceroChains.mainnet.childPool, ...conceroChains.mainnet.parentPool]) {
    const { publicClient } = getClients(chain.viemChain, undefined);
    const usdcAddress = getEnvVar(`USDC_${networkEnvKeys[chain.name]}`) as Address;
    const poolAddress =
      chain.name === "base"
        ? (getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chain.name]}`) as Address)
        : (getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chain.name]}`) as Address);

    const balance = await publicClient.readContract({
      address: usdcAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [poolAddress],
    });

    const loansInUse = await publicClient.readContract({
      address: poolAddress,
      abi: parseAbi(["function s_loansInUse() external returns (uint256)"]),
      functionName: "s_loansInUse",
    });

    childPoolInfo[chain.chainId] = {
      balance,
      loansInUse,
    };
  }

  return childPoolInfo;
}

async function getBatchedAmountsByLane() {
  const batchedAmountsByLane = {};

  for (const chain of conceroChains.mainnet.infra) {
    const { publicClient } = getClients(chain.viemChain, undefined);
    const [infraAddress] = getEnvAddress(ProxyEnum.infraProxy, chain.name);

    if (!batchedAmountsByLane[chain.chainId]) batchedAmountsByLane[chain.chainId] = {};

    for (const _chain of conceroChains.mainnet.infra) {
      if (chain.chainId === _chain.chainId) continue;

      const batchedAmount = await publicClient.readContract({
        address: infraAddress,
        abi: parseAbi(["function s_pendingSettlementTxAmountByDstChain(uint64) external view returns (uint256)"]),
        functionName: "s_pendingSettlementTxAmountByDstChain",
        args: [BigInt(_chain.chainSelector)],
      });

      batchedAmountsByLane[chain.chainId][_chain.chainId] = batchedAmount;
    }
  }

  return batchedAmountsByLane;
}

/* @notice task to display:
 * - pools balances
 * - pools loans in use
 * - batched amounts per lane
 */
task("get-pool-info", "").setAction(async taskArgs => {
  const poolsBaseInfo = await getPoolsBalanceAndLoansInUse();
  const batchedAmountsByLane = await getBatchedAmountsByLane();
  console.log(batchedAmountsByLane);
  const poolBalancesWithPendingBatch = {};

  for (const chain in poolsBaseInfo) {
    let balance = poolsBaseInfo[chain].balance;

    for (const _chain in batchedAmountsByLane) {
      if (chain === _chain) continue;
      balance += batchedAmountsByLane[_chain][chain];
    }

    poolBalancesWithPendingBatch[chain] = balance;
  }

  let totalBalanceWithBatchedAmount = 0n;

  for (const chain in poolBalancesWithPendingBatch) {
    totalBalanceWithBatchedAmount += poolBalancesWithPendingBatch[chain];
  }

  console.log(totalBalanceWithBatchedAmount); // 112_035.298232

  let totalBalanceWithLoansInUse = 0n;

  for (const chain in poolsBaseInfo) {
    totalBalanceWithLoansInUse += poolsBaseInfo[chain].balance + poolsBaseInfo[chain].loansInUse;
  }

  console.log(totalBalanceWithLoansInUse);
});

export default {};

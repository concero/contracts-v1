import { task } from "hardhat/config";
import { conceroChains, networkEnvKeys, ProxyEnum } from "../../../constants";
import { getEnvAddress, getEnvVar, getFallbackClients, log, err } from "../../../utils";
import { erc20Abi, formatUnits } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
interface PoolBalance {
  chain: string;
  address: string;
  usdcBalance: string;
  loansInUse: string;
  withdrawalsOnTheWay?: string;
  depositsOnTheWay?: string;
  withdrawAmountLocked?: string;
  actualBalance: string;
}

async function getPoolBalance(chain: CNetwork, isParent: boolean): Promise<PoolBalance | null> {
  const { abi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  try {
    const contractType = isParent ? "parentPoolProxy" : "childPoolProxy";
    const [poolAddress, _] = getEnvAddress(contractType, chain.name);
    const usdcAddress = getEnvVar(`USDC_${networkEnvKeys[chain.name]}`);
    const { publicClient } = getFallbackClients(chain);

    const usdcBalance = await publicClient.readContract({
      address: usdcAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [poolAddress],
    });

    const loansInUse = await publicClient.readContract({
      address: poolAddress,
      abi: abi,
      functionName: "s_loansInUse",
    });

    let withdrawalsOnTheWay, depositsOnTheWay, withdrawAmountLocked;
    let actualBalance;

    if (isParent) {
      [withdrawalsOnTheWay, depositsOnTheWay, withdrawAmountLocked] = await Promise.all([
        publicClient.readContract({
          address: poolAddress,
          abi: abi,
          functionName: "getWithdrawalsOnTheWayAmount",
        }),
        publicClient.readContract({
          address: poolAddress,
          abi: abi,
          functionName: "s_depositsOnTheWayAmount",
        }),
        publicClient.readContract({
          address: poolAddress,
          abi: abi,
          functionName: "s_withdrawAmountLocked",
        }),
      ]);
      actualBalance =
        BigInt(usdcBalance) +
        BigInt(loansInUse) +
        BigInt(withdrawalsOnTheWay) +
        BigInt(depositsOnTheWay) -
        BigInt(withdrawAmountLocked);
    } else {
      actualBalance = BigInt(usdcBalance) + BigInt(loansInUse);
    }

    return {
      chain: chain.name,
      address: poolAddress,
      usdcBalance: formatUnits(usdcBalance, 6),
      loansInUse: formatUnits(loansInUse, 6),
      ...(isParent && {
        withdrawalsOnTheWay: formatUnits(withdrawalsOnTheWay, 6),
        depositsOnTheWay: formatUnits(depositsOnTheWay, 6),
        withdrawAmountLocked: formatUnits(withdrawAmountLocked, 6),
      }),
      actualBalance: formatUnits(actualBalance, 6),
    };
  } catch (error) {
    err(`Error getting pool balance for ${chain.name}: ${error}`, "getPoolBalance");
    return null;
  }
}

async function getPoolBalances(isTestnet: boolean): Promise<void> {
  const networkType = isTestnet ? "testnet" : "mainnet";
  const { parentPool, childPool } = conceroChains[networkType];

  try {
    const parentPoolNetwork = parentPool[0];
    const promises = [getPoolBalance(parentPoolNetwork, true), ...childPool.map(chain => getPoolBalance(chain, false))];
    const results = await Promise.all(promises);
    const balances = results.filter((balance): balance is PoolBalance => balance !== null);

    if (balances.length > 0) {
      console.log("\nPool Balances:");
      console.table(balances);
    } else {
      console.log("\nNo pool balances available.");
    }
  } catch (error) {
    err(`Error fetching pool balances: ${error}`, "getPoolBalances");
  }
}

task("get-pool-balances", "Get the pool balances")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await getPoolBalances(taskArgs.testnet);
  });

export default getPoolBalances;

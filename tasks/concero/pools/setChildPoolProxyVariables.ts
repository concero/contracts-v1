import { err, getEnvVar, getFallbackClients, log } from "../../../utils";
import {
  conceroNetworks,
  mainnetChains,
  networkEnvKeys,
  networkTypes,
  testnetChains,
  viemReceiptConfig,
} from "../../../constants";

async function setConceroProxySender(hre) {
  const chain = conceroNetworks[hre.network.name];
  const { name: chainName, viemChain, type } = chain;
  const { publicClient, account, walletClient } = getFallbackClients(chain);
  const { abi } = await import("../../../artifacts/contracts/ChildPool.sol/ChildPool.json");
  if (!chainName) throw new Error("Chain name not found");
  const chains = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const dstChain of chains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");
    const dstConceroAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[dstChainName]}`);
    const dstConceroPoolAddress =
      dstChain.chainId === conceroNetworks.base.chainId || dstChain.chainId === conceroNetworks.baseSepolia.chainId
        ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dstChainName]}`)
        : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChainName]}`);
    const conceroPoolAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chainName]}`);

    try {
      const setSenderHash = await walletClient.writeContract({
        address: conceroPoolAddress,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, dstConceroAddress, true],
        abi,
        account,
        viemChain,
      });

      const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setSenderHash,
      });

      log(
        `Set ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${dstConceroAddress}]. Gas used: ${setSenderGasUsed.toString()}`,
        "setConceroContractSender",
      );

      const setPoolHash = await walletClient.writeContract({
        address: conceroPoolAddress,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, dstConceroPoolAddress, true],
        abi,
        account,
        viemChain,
        gas: 1_000_000n,
      });

      const { cumulativeGasUsed: setPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setPoolHash,
      });

      log(
        `Set ${chainName}:${conceroPoolAddress} pool[${dstChainName}:${dstConceroPoolAddress}]. Gas used: ${setPoolGasUsed.toString()}`,
        "setConceroContractSender",
      );
    } catch (error) {
      err(
        `Error setting ${conceroPoolAddress} sender[${dstChainName}:${dstConceroAddress}]`,
        "setConceroContractSender",
        chainName,
      );
      console.error(error);
    }
  }
}

async function addPoolsToAllChains(hre) {
  const chain = conceroNetworks[hre.network.name];
  const { name: chainName, viemChain, type } = chain;
  const { publicClient, account, walletClient } = getFallbackClients(chain);
  const { abi } = await import("../../../artifacts/contracts/ChildPool.sol/ChildPool.json");
  if (!chainName) throw new Error("Chain name not found");
  const chains = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const dstChain of chains) {
    if (dstChain.chainId === chain.chainId) continue;
    // if (dstChain.chainId === conceroNetworks.base.chainId || dstChain.chainId === conceroNetworks.baseSepolia.chainId)
    //   continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    const poolAddressToAdd =
      dstChain.chainId === conceroNetworks.base.chainId || dstChain.chainId === conceroNetworks.baseSepolia.chainId
        ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dstChain.name]}`)
        : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChain.name]}`);

    try {
      if (!dstChainName) throw new Error("Destination chain name not found");
      if (!dstChainSelector) throw new Error("Destination chain selector not found");

      const conceroPoolAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chainName]}`);

      const { request: setPoolReq } = await publicClient.simulateContract({
        address: conceroPoolAddress,
        functionName: "setPools",
        args: [dstChainSelector, poolAddressToAdd],
        abi,
        account,
        viemChain,
        gas: 1_000_000n,
      });
      const setPoolHash = await walletClient.writeContract(setPoolReq);
      const { cumulativeGasUsed: setPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setPoolHash,
      });

      log(`Added pool ${poolAddressToAdd}. Gas used: ${setPoolGasUsed.toString()}`, "addPoolsToAllChains", chainName);
    } catch (error) {
      console.error(error);
    }
  }
}

export async function setChildPoolProxyVariables(hre) {
  // await setConceroProxySender(hre);
  await addPoolsToAllChains(hre);
}

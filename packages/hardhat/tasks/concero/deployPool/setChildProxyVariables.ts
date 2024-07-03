import { CNetwork } from "../../../types/CNetwork";
import { getClients } from "../../utils/switchChain";
import load from "../../../utils/load";
import { getEnvVar } from "../../../utils/getEnvVar";
import chains, { networkEnvKeys } from "../../../constants/CNetworks";
import env from "../../../types/env";
import { Address } from "viem";
import log from "../../../utils/log";

async function setConceroProxySender(hre, liveChains: CNetwork[]) {
  const chain = chains[hre.network.name];
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ChildPool.sol/ChildPool.json");
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");
    const dstConceroContract = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address;
    const conceroPoolAddress = getEnvVar(`CHILDTPROXY_${networkEnvKeys[chainName]}` as keyof env) as Address;

    const { request: setSenderReq } = await publicClient.simulateContract({
      address: conceroPoolAddress,
      functionName: "setConceroContractSender",
      args: [dstChainSelector, dstConceroContract, 1n],
      abi,
      account,
      viemChain,
    });
    const setSenderHash = await walletClient.writeContract(setSenderReq);
    const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setSenderHash,
    });
    log(
      `Set ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${dstConceroContract}]. Gas used: ${setSenderGasUsed.toString()}`,
      "setConceroContractSender",
    );
  }
}

export async function setChildProxyVariables(hre, deployableChains: CNetwork[]) {
  await setConceroProxySender(hre, deployableChains);
}

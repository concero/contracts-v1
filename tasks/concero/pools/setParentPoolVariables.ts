import { CNetwork } from "../../../types/CNetwork";
import {
  formatGas,
  getEnvAddress,
  getEthersV5FallbackSignerAndProvider,
  getFallbackClients,
  shorten,
} from "../../../utils";
import { mainnetChains, networkTypes, ProxyEnum, testnetChains, viemReceiptConfig } from "../../../constants";
import {
  collectLiquidityCodeUrl,
  ethersV6CodeUrl,
  parentPoolJsCodeUrl,
  parentPoolRedistributeLiqJsCodeUrl,
} from "../../../constants/functionsJsCodeUrls";
import { Address } from "viem";
import log, { err } from "../../../utils/log";
import getHashSum from "../../../utils/getHashSum";

import { SecretsManager } from "@chainlink/functions-toolkit";

export async function setParentPoolJsHashes(chain: CNetwork, abi: any) {
  const { viemChain, name } = chain;
  try {
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const [parentPoolProxy, parentPoolAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, name);
    const parentPoolJsCode = await (await fetch(parentPoolJsCodeUrl)).text();
    const ethersCode = await (await fetch(ethersV6CodeUrl)).text();
    const collectLiquidityCode = await (await fetch(collectLiquidityCodeUrl)).text();
    const redistributePoolsLiqCode = await (await fetch(parentPoolRedistributeLiqJsCodeUrl)).text();

    const setHash = async (hash: string, functionName: string) => {
      const setJsHashTxHash = await walletClient.writeContract({
        address: parentPoolProxy,
        abi,
        functionName,
        account,
        args: [hash],
        chain: viemChain,
        gas: 1_000_000n,
      });
      const { cumulativeGasUsed: setHashGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setJsHashTxHash,
      });

      log(`[Set] ${parentPoolAlias}.jsHash -> ${shorten(hash)}. Gas: ${formatGas(setHashGasUsed)}`, functionName, name);
    };

    await setHash(getHashSum(parentPoolJsCode), "setGetBalanceJsCodeHashSum");
    await setHash(getHashSum(collectLiquidityCode), "setCollectLiquidityJsCodeHashSum");
    await setHash(getHashSum(redistributePoolsLiqCode), "setRedistributeLiquidityJsCodeHashSum");

    await setHash(getHashSum(ethersCode), "setEthersHashSum");
  } catch (error) {
    err(`${error?.message}`, "setHashSum", name);
  }
}

async function setParentPoolCap(chain: CNetwork, abi: any) {
  const { name } = chain;
  try {
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const [parentPoolProxy, parentPoolProxyAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, name);
    const poolCap = 100_000n * 10n ** 6n;

    const { request: setCapReq } = await publicClient.simulateContract({
      address: parentPoolProxy,
      abi,
      functionName: "setPoolCap",
      account,
      args: [poolCap],
    });

    const setCapHash = await walletClient.writeContract(setCapReq);
    const { cumulativeGasUsed: setCapGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setCapHash,
    });
    log(
      `[Set] ${parentPoolProxyAlias}.poolCap -> ${poolCap.toString()}. Gas: ${formatGas(setCapGasUsed)}`,
      "setPoolCap",
      name,
    );
  } catch (error) {
    err(`${error?.message}`, "setPoolCap", name);
  }
}

async function setParentPoolSecretsVersion(chain: CNetwork, abi: any, slotId: number) {
  const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, name } = chain;
  try {
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const [parentPoolProxy, parentPoolProxyAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, name);
    const { signer: dcSigner } = getEthersV5FallbackSignerAndProvider(name);

    const secretsManager = new SecretsManager({
      signer: dcSigner,
      functionsRouterAddress: functionsRouter,
      donId: functionsDonIdAlias,
    });
    await secretsManager.initialize();

    const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
    const nodeResponse = result.nodeResponses[0];
    if (!nodeResponse.rows) return log(`No secrets found for ${name}.`, "updateContract");

    const rowBySlotId = nodeResponse.rows.find(row => row.slot_id === slotId);
    if (!rowBySlotId) return log(`No secrets found for ${name} at slot ${slotId}.`, "updateContract");

    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
      address: parentPoolProxy,
      abi,
      functionName: "setDonHostedSecretsVersion",
      account,
      args: [rowBySlotId.version],
    });
    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);

    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setDstConceroContractHash,
    });

    log(
      `[Set] ${parentPoolProxyAlias}.donHostedSecretsVersion -> ${rowBySlotId.version}. Gas: ${formatGas(cumulativeGasUsed)}`,
      "setDonHostedSecretsVersion",
    );
  } catch (error) {
    err(`${error?.message}`, "setDonHostedSecretsVersion", name);
  }
}

async function setParentPoolSecretsSlotId(chain: CNetwork, abi: any, slotId: number) {
  const { name } = chain;
  try {
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const [parentPoolProxy, parentPoolProxyAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, name);

    const { request } = await publicClient.simulateContract({
      address: parentPoolProxy,
      abi,
      functionName: "setDonHostedSecretsSlotId",
      account,
      args: [BigInt(slotId)],
    });

    const hash = await walletClient.writeContract(request);
    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash });

    log(
      `[Set] ${parentPoolProxyAlias}.donHostedSecretsSlotId -> ${slotId}. Gas: ${formatGas(cumulativeGasUsed)}`,
      "setDonHostedSecretsSlotId",
      name,
    );
  } catch (error) {
    err(`Error ${error?.message}`, "setDonHostedSecretsSlotId", name);
  }
}

async function setConceroContractSenders(chain: CNetwork, abi: any) {
  const { name, type } = chain;
  if (!name) throw new Error("Chain name not found");

  const clients = getFallbackClients(chain);
  const { publicClient, account, walletClient } = clients;
  const [parentPoolProxy, parentPoolProxyAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, name);

  const dstChains = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const dstChain of dstChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;

    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");

    const [dstConceroProxy, _] = getEnvAddress(ProxyEnum.infraProxy, dstChainName);
    const [childPoolProxy, __] = getEnvAddress(ProxyEnum.childPoolProxy, dstChainName);

    const setSender = async (sender: Address) => {
      const { request: setSenderReq } = await publicClient.simulateContract({
        address: parentPoolProxy,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, sender, true],
        abi,
        account,
      });
      const setSenderHash = await walletClient.writeContract(setSenderReq);
      const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setSenderHash,
      });
      log(
        `[Set] ${parentPoolProxyAlias}.sender[${dstChainName}] -> ${shorten(sender)}. Gas: ${formatGas(setSenderGasUsed)}`,
        "setSenders",
        name,
      );
    };

    await setSender(dstConceroProxy);
    await setSender(childPoolProxy);
  }
}

async function setPools(chain: CNetwork, abi: any) {
  const { name, type } = chain;
  if (!name) throw new Error("Chain name not found");

  const clients = getFallbackClients(chain);
  const { publicClient, account, walletClient } = clients;

  const dstChains = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const dstChain of dstChains) {
    try {
      if (dstChain.chainId === chain.chainId) continue;
      const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;

      const [parentPoolProxy, parentPoolProxyAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, name);
      const [childPoolProxy, childPoolProxyAlias] = getEnvAddress(ProxyEnum.childPoolProxy, dstChainName);

      const { request: setReceiverReq } = await publicClient.simulateContract({
        address: parentPoolProxy,
        functionName: "setPools",
        args: [dstChainSelector, childPoolProxy, false],
        abi,
        account,
      });
      const setReceiverHash = await walletClient.writeContract(setReceiverReq);
      const { cumulativeGasUsed: setReceiverGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setReceiverHash,
      });
      log(
        `[Set] ${parentPoolProxyAlias}.pool[${dstChainName}] -> ${childPoolProxyAlias}. Gas: ${formatGas(setReceiverGasUsed)}`,
        "setPools",
        name,
      );
    } catch (error) {
      err(`Error ${error?.message}`, "setPools", name);
    }
  }
}

export async function setParentPoolVariables(chain: CNetwork, slotId: number) {
  const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  await setParentPoolSecretsVersion(chain, ParentPoolAbi, slotId);
  await setParentPoolSecretsSlotId(chain, ParentPoolAbi, slotId);

  await setParentPoolJsHashes(chain, ParentPoolAbi);

  await setParentPoolCap(chain, ParentPoolAbi); // once
  await setPools(chain, ParentPoolAbi); // once
  await setConceroContractSenders(chain, ParentPoolAbi); // once
}

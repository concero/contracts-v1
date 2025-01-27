import { task } from "hardhat/config";
import { conceroNetworks, ProxyEnum } from "../../../constants";
import { getEnvAddress, getFallbackClients, log } from "../../../utils";

task("add-new-pool-to-parent-pool", "Add a new pool to the parent pool with rebalancing")
  .addParam("newchain", "", "")
  .setAction(async taskArgs => {
    console.log(`Adding ${taskArgs.newchain} to the parent pool`);
    const hre = require("hardhat");
    const parentPoolChain = conceroNetworks[hre.network.name];
    const { publicClient, walletClient } = getFallbackClients(parentPoolChain);
    const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");
    const newPoolChain = conceroNetworks[taskArgs.newchain];
    if (!newPoolChain) {
      throw new Error(`No chain found for ${taskArgs.newchain}`);
    }
    const newPoolChainSelector = newPoolChain.chainSelector;
    const [newPoolAddress] = getEnvAddress(ProxyEnum.childPoolProxy, newPoolChain.name);
    const [parentPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolChain.name);

    const txHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      address: parentPoolAddress,
      functionName: "setPools",
      args: [newPoolChainSelector, newPoolAddress, true],
      gas: 3_000_000n,
    });

    const { transactionHash, status } = await publicClient.waitForTransactionReceipt({ hash: txHash });
    log(`set parent pool ${status}, tx: ${transactionHash}`, "setPools", parentPoolChain.name);
  });

export default {};

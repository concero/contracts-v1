import { task } from "hardhat/config";
import { conceroNetworks, ProxyEnum } from "../../../constants";
import { getEnvAddress, getFallbackClients, log } from "../../../utils";

task("add-new-pool-to-child-pool", "Add a new pool to the child pool")
  .addParam("newchain", "", "")
  .setAction(async taskArgs => {
    const hre = require("hardhat");
    const currentPoolChain = conceroNetworks[hre.network.name];
    const { publicClient, walletClient } = getFallbackClients(currentPoolChain);
    const { abi: ChildPoolAbi } = await import("../../../artifacts/contracts/ChildPool.sol/ChildPool.json");
    const newPoolChain = conceroNetworks[taskArgs.newchain];
    if (!newPoolChain) {
      throw new Error(`No chain found for ${taskArgs.newchain}`);
    }
    const newPoolChainSelector = newPoolChain.chainSelector;
    const [newPoolAddress] = getEnvAddress(ProxyEnum.childPoolProxy, newPoolChain.name);
    const [currentPoolAddress] = getEnvAddress(ProxyEnum.childPoolProxy, currentPoolChain.name);

    const setPoolsTxHash = await walletClient.writeContract({
      abi: ChildPoolAbi,
      functionName: "setPools",
      address: currentPoolAddress,
      args: [newPoolChainSelector, newPoolAddress],
      gas: 3_000_000n,
    });
    const { status: setPoolsStatus } = await publicClient.waitForTransactionReceipt({ hash: setPoolsTxHash });
    log(`set child pool ${setPoolsStatus}`, "setPools", currentPoolChain.name);

    const allowContractSenderTxHash = await walletClient.writeContract({
      abi: ChildPoolAbi,
      address: currentPoolAddress,
      functionName: "setConceroContractSender",
      args: [newPoolChainSelector, newPoolAddress, true],
      gas: 3_000_000n,
    });

    const { transactionHash, status: allowContractSenderStatus } = await publicClient.waitForTransactionReceipt({
      hash: allowContractSenderTxHash,
    });
    log(
      `set child pool ${allowContractSenderStatus}. tx: ${transactionHash}`,
      "setConceroContractSender",
      currentPoolChain.name,
    );
  });

export default {};

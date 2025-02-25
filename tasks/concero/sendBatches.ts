import { task } from "hardhat/config";
import { getClients, getEnvVar } from "../../utils";
import { conceroNetworks, networkEnvKeys } from "../../constants";
import { Address } from "viem";

task("send-batches", "").setAction(async taskArgs => {
  const hre = require("hardhat");
  const name = hre.network.name;
  const { walletClient, publicClient } = getClients(conceroNetworks[name].viemChain);
  const infraAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`) as Address;

  const sendBatchesReq = (
    await publicClient.simulateContract({
      account: walletClient.account,
      abi: (await import("../../artifacts/contracts/InfraOrchestrator.sol/InfraOrchestrator.json")).abi,
      address: infraAddress,
      functionName: "sendBatches",
      args: [],
    })
  ).request;
  const sendBatchesHash = await walletClient.writeContract(sendBatchesReq);
  const sendBatchesStatus = (await publicClient.waitForTransactionReceipt({ hash: sendBatchesHash })).status;
  if (sendBatchesStatus === "success") {
    console.log("sendBatches success", sendBatchesHash);
  } else {
    console.log("sendBatches failed", sendBatchesHash);
  }
});

export default {};

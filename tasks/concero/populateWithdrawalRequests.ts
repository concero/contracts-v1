import { task } from "hardhat/config";
import { log, getClients, getEnvVar } from "../../utils";
import { conceroNetworks, networkEnvKeys } from "../../constants";
import fs from "fs";

task("populate-withdrawal-requests", "Reads withdrawal statuses from JSON and updates the contract").setAction(
  async (taskArgs, hre) => {
    const chain = conceroNetworks.base;
    try {
      const { publicClient, walletClient, account } = getClients(chain.name, chain.url);
      const contractAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chain.name]}`);

      const { abi: parentPoolAbi } = await import("../../artifacts/contracts/ParentPool.sol/ParentPool.json");

      // Read JSON file
      const jsonData = fs.readFileSync("withdrawal-statuses.json", "utf8");
      const withdrawalStatuses = JSON.parse(jsonData);

      // Prepare data for contract call
      const withdrawalIds = withdrawalStatuses.map(status => status.id);
      const isTriggered = withdrawalStatuses.map(status => status.isTriggered);

      // Split data into chunks to avoid gas limit issues
      const chunkSize = 200; // Adjust based on gas limit and contract requirements
      for (let i = 0; i < withdrawalIds.length; i += chunkSize) {
        const idChunk = withdrawalIds.slice(i, i + chunkSize);
        const triggeredChunk = isTriggered.slice(i, i + chunkSize);

        // Prepare transaction
        const { request } = await publicClient.simulateContract({
          address: contractAddress,
          abi: parentPoolAbi,
          functionName: "dev_addWithdrawalIds",
          args: [idChunk, triggeredChunk],
          account,
          chain: chain.viemChain,
        });

        // Send transaction
        const hash = await walletClient.writeContract(request);

        log(`Transaction sent: ${hash}`, "populate-withdrawal-requests", chain.name);

        // Wait for transaction to be mined
        const receipt = await publicClient.waitForTransactionReceipt({ hash });

        log(
          `Chunk ${i / chunkSize + 1} processed. Transaction hash: ${receipt.transactionHash}`,
          "populate-withdrawal-requests",
          chain.name,
        );
      }

      log("All withdrawal requests have been populated", "populate-withdrawal-requests", chain.name);
    } catch (error) {
      log(`Error: ${error.message}`, "populate-withdrawal-requests", chain.name, "error");
    }
  },
);

export default {};

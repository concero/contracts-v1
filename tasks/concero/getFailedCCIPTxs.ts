import { task } from "hardhat/config";
import { Address } from "viem";

const BATCH_SIZE = 10;

export async function getFailedCCIPTxs(targetContract: Address) {
  let offset = 0;
  const limit = 100;

  try {
    while (true) {
      const requests = Array.from({ length: BATCH_SIZE }, (_, i) => {
        const currentOffset = offset + i * limit;
        const url = `https://ccip.chain.link/api/h/atlas/transactions?first=${limit}&offset=${currentOffset}&sender=${targetContract.toLowerCase()}`;
        return fetch(url).then(async response => {
          if (!response.ok) {
            throw new Error(`Request failed with status ${response.status}: ${response.statusText}`);
          }
          const data = await response.json();
          return { data, offset: currentOffset };
        });
      });

      let batchData;
      try {
        batchData = await Promise.all(requests);
      } catch (error) {
        console.error("Error fetching transactions:", error);
      }

      const emptyResponse = batchData.find(item => !Array.isArray(item.data) || item.data.length === 0);

      for (const { data } of batchData) {
        if (!Array.isArray(data) || data.length === 0) {
          break;
        }

        console.log(`Fetched ${data.length} entries`);
        const failedStates = data.filter(item => item.state !== 2);
        for (const entry of failedStates) {
          console.log(`Unsuccessful CCIP message id: ${entry.messageId}, state: ${entry.state}`);
        }
      }

      if (emptyResponse) break;

      offset += BATCH_SIZE * limit;
    }
  } catch (error) {
    console.error("Error fetching transactions:", error);
  }
}

task("get-failed-ccip-txs", "Get failed CCIPTxs")
  .addParam("contract", "The address of the target CCIP consumer contract")
  .setAction(async (args, hre) => {
    await getFailedCCIPTxs(args.contract);
  });

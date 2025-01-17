import { ProxyEnum, viemReceiptConfig } from "../../constants/deploymentVariables";
import { getFallbackClients } from "../../utils/getViemClients";
import { getEnvAddress } from "../../utils/getEnvVar";
import log from "../../utils/log";
import { task } from "hardhat/config";
import conceroNetworks from "../../constants/conceroNetworks";

export async function deleteDepositsOTWIds() {
  const chain = conceroNetworks.base;

  const { walletClient, publicClient, account } = getFallbackClients(chain);
  const gasPrice = await publicClient.getGasPrice();

  const [parentPoolProxy, _] = getEnvAddress(ProxyEnum.parentPoolProxy, chain.name);
  const idsToDelete = [
    "0xc6",
    "0xc5",
    "0xc4",
    "0xbc",
    "0x02",
    "0x03",
    "0x07",
    "0x08",
    "0x09",
    "0x0a",
    "0x0b",
    "0x0c",
    "0x0d",
    "0x0e",
    "0x0f",
    "0x10",
    "0x11",
    "0x01",
    "0x04",
    "0x05",
    "0x06",
    "0x16",
    "0x17",
    "0x18",
    "0x15",
    "0x1a",
    "0x1b",
    "0x1c",
    "0x1d",
    "0x1e",
    "0x1f",
    "0x20",
    "0x21",
    "0x22",
    "0x23",
    "0x24",
    "0x19",
    "0x1a",
    "0x1b",
    "0x1c",
    "0x1d",
    "0x1e",
    "0x1f",
    "0x20",
    "0x21",
    "0x22",
    "0x23",
    "0x24",
    "0x2b",
    "0x2c",
    "0x2d",
    "0x2e",
    "0x2f",
    "0x30",
    "0x34",
    "0x35",
    "0x36",
    "0x3a",
    "0x3b",
    "0x3c",
    "0x3d",
    "0x3e",
    "0x3f",
    "0x40",
    "0x41",
    "0x42",
    "0x52",
    "0x53",
    "0x54",
    "0x55",
    "0x56",
    "0x57",
    "0x5e",
    "0x5f",
    "0x60",
    "0x61",
    "0x62",
    "0x63",
    "0x67",
    "0x68",
    "0x69",
    "0x6a",
    "0x6b",
    "0x6c",
    "0xb2",
    "0xb3",
    "0xb4",
    "0xb5",
    "0xb6",
    "0xb7",
    "0xb8",
    "0xb9",
    "0xba",
    "0xbe",
    "0xbf",
    "0xc0",
    "0xc4",
    "0xc5",
    "0xc6",
    "0xc7",
    "0xc8",
    "0xc9",
    "0xd0",
    "0xd1",
    "0xd2",
    "0xd6",
    "0xd7",
    "0xd8",
    "0xdf",
    "0xe0",
    "0xe1",
    "0xe2",
    "0xe3",
    "0xe4",
    "0xe5",
    "0xe6",
    "0xe7",
    "0xe8",
    "0xe9",
    "0xea",
    "0xeb",
    "0xec",
    "0xed",
    "0xee",
    "0xef",
    "0xf0",
    "0xf4",
    "0xf5",
    "0x46",
    "0x47",
    "0x7c",
    "0x7d",
    "0x82",
    "0x83",
    "0x84",
    "0x85",
    "0x86",
    "0x8b",
    "0x8c",
    "0x91",
    "0x92",
    "0x93",
    "0x94",
    "0x95",
    "0x96",
    "0x97",
    "0x98",
    "0x99",
    "0x9a",
    "0x9b",
    "0xa0",
    "0xa1",
    "0xa2",
    "0xa3",
    "0xa4",
    "0xa5",
    "0xa6",
    "0xa7",
    "0xa8",
    "0xa9",
    "0xaa",
    "0xab",
    "0xac",
    "0xad",
    "0xb2",
    "0xb3",
    "0xb4",
    "0xf7",
    "0xf8",
    "0xf9",
  ];
  // Split ids into chunks of 15
  const chunkSize = 13;
  const idChunks = [];
  for (let i = 0; i < idsToDelete.length; i += chunkSize) {
    idChunks.push(idsToDelete.slice(i, i + chunkSize));
  }

  for (let i = 0; i < idChunks.length; i++) {
    const chunk = idChunks[i];

    const { request: sendReq } = await publicClient.simulateContract({
      functionName: "deleteDepositsOnTheWayByIds",
      //    function deleteDepositsOnTheWayByIds(bytes1[] calldata _ids) external onlyOwner {
      abi: [
        {
          inputs: [{ internalType: "bytes1[]", name: "_ids", type: "bytes1[]" }],
          stateMutability: "nonpayable",
          type: "function",
          name: "deleteDepositsOnTheWayByIds",
          outputs: [],
        },
      ],
      account,
      address: parentPoolProxy,
      args: [chunk],
      gasPrice,
    });

    const sendHash = await walletClient.writeContract(sendReq);
    const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: sendHash,
    });
    log(
      `Deleted deposit on the way with from ${parentPoolProxy}. Tx: ${sendHash} Gas used: ${sendGasUsed}`,
      "deleteDepositsOTWIds",
      chain.name,
    );
  }
}

task("delete-deposits-otw-ids", "Deletes deposits on the way by id").setAction(async (taskArgs, hre) => {
  await deleteDepositsOTWIds();
});

export default {};

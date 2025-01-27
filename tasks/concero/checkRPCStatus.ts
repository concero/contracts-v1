import { task } from "hardhat/config";
import axios, { AxiosInstance } from "axios";
import { setTimeout } from "timers/promises";
import { urls as rpcUrls } from "../../constants";

const CONFIG = {
  TIMEOUT_MS: 5000,
  RETRY_ATTEMPTS: 2,
  RETRY_DELAY_MS: 1000,
  CONCURRENT_REQUESTS: 10,
  LOG_LEVEL: "info", // 'debug' | 'info' | 'error'
};

interface RpcResponse {
  networkName: string;
  url: string;
  status: "OK" | "ERROR";
  latency: number;
  errorMessage?: string;
}

const createAxiosInstance = (): AxiosInstance => {
  return axios.create({
    timeout: CONFIG.TIMEOUT_MS,
    headers: {
      "Content-Type": "application/json",
    },
  });
};

const rpcRequest = {
  jsonrpc: "2.0",
  method: "eth_blockNumber",
  params: [],
  id: 1,
};

async function checkSingleRpc(
  networkName: string,
  url: string,
  axiosInstance: AxiosInstance,
  attempt = 1,
): Promise<RpcResponse> {
  const startTime = Date.now();
  try {
    const response = await axiosInstance.post(url, rpcRequest);
    const latency = Date.now() - startTime;

    if (response.data?.result) {
      return {
        networkName,
        url: new URL(url).origin,
        status: "OK",
        latency,
      };
    }
    throw new Error("Invalid response format");
  } catch (error) {
    if (attempt < CONFIG.RETRY_ATTEMPTS) {
      await setTimeout(CONFIG.RETRY_DELAY_MS);
      return checkSingleRpc(networkName, url, axiosInstance, attempt + 1);
    }

    return {
      networkName,
      url: new URL(url).origin,
      status: "ERROR",
      latency: Date.now() - startTime,
      errorMessage: error.message,
    };
  }
}

async function processBatch(batch: [string, string][], axiosInstance: AxiosInstance): Promise<RpcResponse[]> {
  return Promise.all(batch.map(([networkName, url]) => checkSingleRpc(networkName, url, axiosInstance)));
}

export async function checkRpcStatus() {
  const axiosInstance = createAxiosInstance();
  const allChecks: [string, string][] = [];

  for (const [networkName, urls] of Object.entries(rpcUrls)) {
    urls.forEach(url => {
      allChecks.push([networkName, url]);
    });
  }

  const results: RpcResponse[] = [];
  for (let i = 0; i < allChecks.length; i += CONFIG.CONCURRENT_REQUESTS) {
    const batch = allChecks.slice(i, i + CONFIG.CONCURRENT_REQUESTS);
    const batchResults = await processBatch(batch, axiosInstance);
    results.push(...batchResults);
  }

  const groupedResults = results.reduce(
    (acc, result) => {
      if (!acc[result.networkName]) {
        acc[result.networkName] = [];
      }
      acc[result.networkName].push(result);
      return acc;
    },
    {} as Record<string, RpcResponse[]>,
  );

  Object.entries(groupedResults).forEach(([networkName, networkResults]) => {
    console.log(`\n=== ${networkName.toUpperCase()} RPC Status ===`);
    console.table(
      networkResults.map(r => ({
        URL: r.url,
        Status: r.status,
        Latency: `${r.latency}ms`,
        Error: r.errorMessage || "N/A",
      })),
    );
  });

  const summary = {
    total: results.length,
    successful: results.filter(r => r.status === "OK").length,
    failed: results.filter(r => r.status === "ERROR").length,
    averageLatency: Math.round(results.reduce((acc, r) => acc + r.latency, 0) / results.length),
  };

  console.log("\n=== Summary ===");
  console.table([summary]);
}

task("check-rpc-status", "Check the status of all RPC endpoints").setAction(async (_, hre) => {
  await checkRpcStatus();
});

export default {};

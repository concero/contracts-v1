import { CNetwork } from "../types/CNetwork";
import { getFallbackClients } from "./getViemClients";
import { type PublicClient } from "viem";

interface GasParameters {
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
}

// Network-specific minimum gas parameters (in wei)
const NETWORK_MINIMUMS = {
  polygon: {
    minTipCap: BigInt(30_000_000_000), // 30 gwei
    minBaseFee: BigInt(30_000_000_000), // 30 gwei
  },
  // Add other networks as needed
} as const;

/**
 * Gets optimized gas parameters for priority transaction processing
 * @param chain - The network configuration
 * @param priorityMultiplier - Multiplier for maxPriorityFeePerGas (default: 2)
 * @param maxFeeMultiplier - Multiplier for maxFeePerGas buffer (default: 2)
 * @returns GasParameters object containing maxFeePerGas and maxPriorityFeePerGas
 */
export async function getGasParameters(
  chain: CNetwork,
  priorityMultiplier = 2,
  maxFeeMultiplier = 2,
): Promise<GasParameters> {
  const { publicClient } = getFallbackClients(chain);

  try {
    // Get latest block to calculate gas parameters
    const block = await publicClient.getBlock();
    const baseFee = block.baseFeePerGas ?? BigInt(0);

    // Get network-specific minimums
    const networkMinimums = getNetworkMinimums(chain);

    // Calculate priority fee with buffer for faster inclusion
    const suggestedPriorityFee = await getSuggestedPriorityFee(publicClient, chain);
    const calculatedPriorityFee = calculatePriorityFee(suggestedPriorityFee, priorityMultiplier);

    // Ensure priority fee meets network minimum
    const priorityFee =
      calculatedPriorityFee > networkMinimums.minTipCap ? calculatedPriorityFee : networkMinimums.minTipCap;

    // Calculate max fee ensuring it meets network minimums
    const calculatedMaxFee = calculateMaxFee(baseFee, priorityFee, maxFeeMultiplier);
    const minRequiredMaxFee = networkMinimums.minBaseFee + priorityFee;
    const maxFeePerGas = calculatedMaxFee > minRequiredMaxFee ? calculatedMaxFee : minRequiredMaxFee;

    return {
      maxFeePerGas,
      maxPriorityFeePerGas: priorityFee,
    };
  } catch (error) {
    // Fallback with network minimums
    const networkMinimums = getNetworkMinimums(chain);
    const gasPrice = await publicClient.getGasPrice();
    const priorityFee = networkMinimums.minTipCap;

    return {
      maxFeePerGas:
        gasPrice > networkMinimums.minBaseFee + priorityFee ? gasPrice : networkMinimums.minBaseFee + priorityFee,
      maxPriorityFeePerGas: priorityFee,
    };
  }
}

/**
 * Gets network-specific minimum gas parameters
 */
function getNetworkMinimums(chain: CNetwork) {
  // Check if chain is Polygon (you'll need to implement this check based on your CNetwork type)
  const isPolygon = chain.chainId === 137 || chain.name.toLowerCase().includes("polygon");

  if (isPolygon) {
    return NETWORK_MINIMUMS.polygon;
  }

  // Default minimums for other networks
  return {
    minTipCap: BigInt(1_500_000_000), // 1.5 gwei
    minBaseFee: BigInt(1_000_000_000), // 1 gwei
  };
}

/**
 * Gets the suggested priority fee from recent blocks
 */
async function getSuggestedPriorityFee(publicClient: PublicClient, chain: CNetwork): Promise<bigint> {
  try {
    // For Polygon, we want to be more aggressive with priority fees
    const isPolygon = chain.chainId === 137 || chain.name.toLowerCase().includes("polygon");
    const blocksToAnalyze = isPolygon ? 5 : 10; // Look at fewer blocks on Polygon for more recent data

    const blocks = await Promise.all(
      Array.from({ length: blocksToAnalyze }, (_, i) => publicClient.getBlock({ blockNumber: BigInt(-1 - i) })),
    );

    // For Polygon, use 75th percentile instead of median for higher priority
    const priorityFees = blocks.map(block => block.baseFeePerGas ?? BigInt(0)).sort((a, b) => (a < b ? -1 : 1));

    const index = isPolygon ? Math.floor(priorityFees.length * 0.75) : Math.floor(priorityFees.length * 0.5);

    return priorityFees[index];
  } catch {
    // Use network-specific minimum as fallback
    return getNetworkMinimums(chain).minTipCap;
  }
}

/**
 * Calculates priority fee with buffer
 */
function calculatePriorityFee(basePriorityFee: bigint, multiplier: number): bigint {
  return BigInt(Math.ceil(Number(basePriorityFee) * multiplier));
}

/**
 * Calculates max fee with buffer
 */
function calculateMaxFee(baseFee: bigint, priorityFee: bigint, multiplier: number): bigint {
  return BigInt(Math.ceil(Number(baseFee) * multiplier)) + priorityFee;
}

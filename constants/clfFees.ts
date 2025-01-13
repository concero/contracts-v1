import { CNetworkNames } from "../types/CNetwork";

export const clfFees: Record<CNetworkNames, bigint> = {
  polygon: 40000000000000000n,
  arbitrum: 75000000000000000n,
  base: 60000000000000000n,
  avalanche: 280000000000000000n,

  // testnets

  polygonAmoy: 36000000000000000n,
  arbitrumSepolia: 75000000000000000n,
  baseSepolia: 60000000000000000n,
  avalancheFuji: 280000000000000000n,
};

export const defaultCLFfee = 80000000000000000n;

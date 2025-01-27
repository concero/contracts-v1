import { CNetwork } from "../types/CNetwork";
import { conceroNetworks } from "./conceroNetworks";
import { ConceroChains } from "../types/chains";

export const liveChains: CNetwork[] = [
  conceroNetworks.baseSepolia,
  conceroNetworks.arbitrumSepolia,
  // conceroNetworks.avalancheFuji,
  // conceroNetworks.optimismSepolia,
  // conceroNetworks.polygonAmoy,
];

// export const liveChains: CNetwork[] = [conceroNetworks.polygon, conceroNetworks.base, conceroNetworks.arbitrum, conceroNetworks.avalanche];

export const conceroChains: ConceroChains = {
  testnet: {
    parentPool: [conceroNetworks.baseSepolia],
    childPool: [conceroNetworks.arbitrumSepolia, conceroNetworks.avalancheFuji],
    infra: [conceroNetworks.arbitrumSepolia, conceroNetworks.avalancheFuji, conceroNetworks.baseSepolia],
  },
  mainnet: {
    parentPool: [conceroNetworks.base],
    childPool: [
      conceroNetworks.polygon,
      conceroNetworks.arbitrum,
      conceroNetworks.avalanche,
      // conceroNetworks.ethereum,
      conceroNetworks.optimism,
    ],
    infra: [
      conceroNetworks.polygon,
      conceroNetworks.arbitrum,
      conceroNetworks.avalanche,
      conceroNetworks.base,
      // conceroNetworks.ethereum,
      conceroNetworks.optimism,
    ],
  },
};

export const testnetChains: CNetwork[] = Array.from(
  new Set([...conceroChains.testnet.parentPool, ...conceroChains.testnet.childPool, ...conceroChains.testnet.infra]),
);

export const mainnetChains: CNetwork[] = Array.from(
  new Set([...conceroChains.mainnet.parentPool, ...conceroChains.mainnet.childPool, ...conceroChains.mainnet.infra]),
);

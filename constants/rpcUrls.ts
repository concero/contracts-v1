const { INFURA_API_KEY, DRPC_API_KEY, ALCHEMY_API_KEY, BLAST_API_KEY, CHAINSTACK_API_KEY, TENDERLY_API_KEY } =
  process.env;

export const rpc: Record<string, string> = {
  arbitrum: `https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}`,
  arbitrumSepolia: `https://arbitrum-sepolia.infura.io/v3/${INFURA_API_KEY}`,
  base: `https://base.infura.io/v3/${INFURA_API_KEY}`,
  baseSepolia: `https://base-sepolia.infura.io/v3/${INFURA_API_KEY}`,
  avalanche: `https://avalanche-mainnet.infura.io/v3/${INFURA_API_KEY}`,
  avalancheFuji: `https://avalanche-fuji.infura.io/v3/${INFURA_API_KEY}`,
  ethereum: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
  sepolia: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
  optimism: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
  optimismSepolia: `https://optimism-sepolia.infura.io/v3/${INFURA_API_KEY}`,
  polygon: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
  polygonAmoy: `https://polygon-amoy.infura.io/v3/${INFURA_API_KEY}`,
};

// Warning: ANKR endpoints are limited to 30 requests/sec and not suitable for production use

export const urls: Record<string, string[]> = {
  ethereum: [
    `https://lb.drpc.org/ogrpc?network=ethereum&dkey=${DRPC_API_KEY}`,
    `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
    `https://eth-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/eth",
  ],
  sepolia: [
    `https://lb.drpc.org/ogrpc?network=sepolia&dkey=${DRPC_API_KEY}`,
    `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://eth-sepolia.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/eth_sepolia",
  ],
  avalanche: [
    `https://lb.drpc.org/ogrpc?network=avalanche&dkey=${DRPC_API_KEY}`,
    `https://ava-mainnet.blastapi.io/${BLAST_API_KEY}ext/bc/C/rpc`,
    "https://rpc.ankr.com/avalanche",
    `https://avalanche-mainnet.infura.io/v3/${INFURA_API_KEY}`,
  ],
  avalancheFuji: [
    `https://lb.drpc.org/ogrpc?network=avalanche-fuji&dkey=${DRPC_API_KEY}`,
    `https://avalanche-fuji.infura.io/v3/${INFURA_API_KEY}`,
    `https://avalanche-fuji.core.chainstack.com/ext/bc/C/rpc/${CHAINSTACK_API_KEY}`,
    `https://ava-testnet.blastapi.io/${BLAST_API_KEY}ext/bc/C/rpc`,
  ],
  arbitrum: ["https://rpc.ankr.com/arbitrum", "https://arbitrum-one-rpc.publicnode.com"],
  arbitrumSepolia: [
    `https://lb.drpc.org/ogrpc?network=arbitrum-sepolia&dkey=${DRPC_API_KEY}`,
    `https://arbitrum-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://arbitrum-sepolia.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/arbitrum_sepolia",
  ],
  optimism: [
    `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    `https://lb.drpc.org/ogrpc?network=optimism&dkey=${DRPC_API_KEY}`,
    "https://optimism.llamarpc.com",
    `https://optimism-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/optimism",
  ],
  optimismSepolia: [
    `https://lb.drpc.org/ogrpc?network=optimism-sepolia&dkey=${DRPC_API_KEY}`,
    `https://optimism-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://optimism-sepolia.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/optimism_sepolia",
  ],
  polygon: [
    `https://lb.drpc.org/ogrpc?network=polygon&dkey=${DRPC_API_KEY}`,
    `https://polygon.gateway.tenderly.co/${TENDERLY_API_KEY}`,
    `https://polygon-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/polygon",
    `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    "https://polygon-bor-rpc.publicnode.com",
  ],
  polygonAmoy: [
    `https://lb.drpc.org/ogrpc?network=polygon-amoy&dkey=${DRPC_API_KEY}`,
    `https://polygon-amoy.blastapi.io/${BLAST_API_KEY}`,
    `https://polygon-amoy.infura.io/v3/${INFURA_API_KEY}`,
  ],
  base: [
    // `https://lb.drpc.org/ogrpc?network=base&dkey=${DRPC_API_KEY}`,
    // "https://base.llamarpc.com",
    "https://base.blockpi.network/v1/rpc/public",
    `https://base-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    `https://base-rpc.publicnode.com`,
    "https://rpc.ankr.com/base",
    `https://base-mainnet.blastapi.io/${BLAST_API_KEY}`,
  ],
  baseSepolia: [
    `https://lb.drpc.org/ogrpc?network=base-sepolia&dkey=${DRPC_API_KEY}`,
    `https://base-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://base-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    "https://rpc.ankr.com/base_sepolia",
    `https://base-sepolia.blastapi.io/${BLAST_API_KEY}`,
  ],
  bsc: ["https://rpc.ankr.com/bsc"],
  scroll: ["https://rpc.ankr.com/scroll"],
  scrollSepolia: ["https://rpc.ankr.com/scroll_sepolia"],
  polygonZkEvm: [`https://polygon-zkevm-mainnet.blastapi.io/${BLAST_API_KEY}`],
  polygonZkEvmCardona: [`https://polygon-zkevm-cardona.blastapi.io/${BLAST_API_KEY}`],
};

export default rpc;

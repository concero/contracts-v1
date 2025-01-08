// Purpose: To have a single source of truth for networks across the project
import {NetworkUserConfig} from 'hardhat/types';
import {HttpNetworkUserConfig} from 'hardhat/src/types/config';
import {Chain} from 'viem';

export type envString = string | undefined;

export type CNetworkNames = "localhost" | "hardhat" |
  "ethereum" | "arbitrum" | "optimism" | "polygon" | "polygonZkEvm" | "avalanche" | "base" | "sepolia" | "optimismSepolia" | "arbitrumSepolia" | "avalancheFuji" | "baseSepolia" | "polygonAmoy";

export type NetworkType = "mainnet" | "testnet";

export type CLFNetwork = {
  saveDeployments: boolean;
  functionsRouter: envString;
  functionsCoordinator: envString;
  functionsDonId: envString;
  functionsDonIdAlias: envString;
  functionsSubIds: envString[];
  functionsGatewayUrls: string[];
  gatewayUrls: string[];
  confirmations: number;
  chainSelector: envString;
  conceroChainIndex: string;
  donHostedSecretsVersion: envString;
  linkToken: envString;
  linkPriceFeed: envString;
  //concero fields
  viemChain: Chain;
  name: CNetworkNames;
  urls: string[];
  type: NetworkType;
};

interface PriceFeed {
  linkToUsdPriceFeeds: string,
  usdcToUsdPriceFeeds: string,
  nativeToUsdPriceFeeds: string,
  linkToNativePriceFeeds: string,
}

// Chainlink CCIP Network specific configuration
export type CLCCIPNetwork = {
  linkToken: envString;
  ccipBnmToken: envString;
  usdc: envString;
  ccipRouter: envString;
  chainSelector: envString;
  priceFeed: PriceFeed;
};

// Combined network configuration type
export type CNetwork = NetworkUserConfig & HttpNetworkUserConfig & Partial<CLFNetwork> & Partial<CLCCIPNetwork>;

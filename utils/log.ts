import { CNetworkNames } from "../types/CNetwork";

const networkColors: Record<CNetworkNames, string> = {
  localhost: "\x1b[30m", //grey
  ethereum: "\x1b[30m", // grey
  arbitrum: "\x1b[34m", // blue
  polygon: "\x1b[35m", // magenta
  avalanche: "\x1b[31m", // red
  base: "\x1b[36m", // cyan
  sepolia: "\x1b[30m", // grey
  arbitrumSepolia: "\x1b[34m", // blue
  optimismSepolia: "\x1b[31m", // red
  optimism: "\x1b[31m", // red
  polygonZkEvm: "\x1b[35m", // magenta
  polygonAmoy: "\x1b[35m", // magenta
  avalancheFuji: "\x1b[31m", // red
  baseSepolia: "\x1b[36m", // cyan
};
const reset = "\x1b[0m";

export function log(message: any, functionName: string, networkName?: CNetworkNames) {
  const greenFill = "\x1b[32m";
  const network = networkName ? `${networkColors[networkName]}[${networkName}]${reset}` : "";

  console.log(`${network}${greenFill}[${functionName}]${reset}`, message);
}

export function warn(message: any, functionName: string) {
  const yellowFill = "\x1b[33m";

  console.log(`${yellowFill}[${functionName}]${reset}`, message);
}

export function err(message: any, functionName: string, networkName?: CNetworkNames) {
  const redFill = "\x1b[31m";
  const network = networkName ? `${networkColors[networkName]}[${networkName}]${reset}` : "";

  console.log(`${network}${redFill}[${functionName}] ERROR:${reset}`, message);
}

export default log;

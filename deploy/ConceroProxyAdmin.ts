import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import conceroNetworks from "../constants/conceroNetworks";
import { getEnvVar, updateEnvAddress } from "../utils";
import log from "../utils/log";

import { IProxyType } from "../types/deploymentVariables";
import { getGasParameters } from "../utils/getGasPrice";

const deployProxyAdmin: (hre: HardhatRuntimeEnvironment, proxyType: IProxyType) => Promise<void> = async function (
  hre: HardhatRuntimeEnvironment,
  proxyType: IProxyType,
) {
  const { proxyDeployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const networkType = conceroNetworks[name].type;

  const initialOwner = getEnvVar(`PROXY_DEPLOYER_ADDRESS`);
  const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name]);

  log("Deploying...", `deployProxyAdmin: ${proxyType}`, name);
  const deployProxyAdmin = (await deploy("ConceroProxyAdmin", {
    from: proxyDeployer,
    args: [initialOwner],
    log: true,
    autoMine: true,
    maxFeePerGas,
    maxPriorityFeePerGas,
  })) as Deployment;

  if (live) {
    log(`Deployed at: ${deployProxyAdmin.address}`, `deployProxyAdmin: ${proxyType}`, name);
    updateEnvAddress(`${proxyType}Admin`, name, deployProxyAdmin.address, `deployments.${networkType}`);
  }
};

export default deployProxyAdmin;
deployProxyAdmin.tags = ["ConceroProxyAdmin"];

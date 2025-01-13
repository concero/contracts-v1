import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { zeroAddress } from "viem";
import { getEnvVar, getFallbackClients } from "../utils";
import { poolMessengers } from "../constants";
import { getGasParameters } from "../utils/getGasPrice";

interface Args {
  parentProxyAddress: string;
  parentPoolCLFCLA: string;
  linkToken: string;
  ccipRouter: string;
  usdc: string;
  lpToken: string;
  clfRouter: string;
  infraProxyAddress: string;
  owner: string;
  poolMessengers: string[];
  automationForwarder: string;
}

const deployParentPool: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = conceroNetworks[name].type;
    const { linkToken, ccipRouter, functionsRouter, functionsDonId, functionsSubIds } = conceroNetworks[name];

    const defaultArgs: Args = {
      parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
      parentPoolCLFCLA: getEnvVar(`PARENT_POOL_CLF_CLA_${networkEnvKeys[name]}`),
      linkToken: linkToken,
      ccipRouter: ccipRouter,
      usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
      lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
      clfRouter: functionsRouter,
      infraProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
      owner: deployer,
      poolMessengers,
      automationForwarder: getEnvVar(`PARENT_POOL_AUTOMATION_FORWARDER_${networkEnvKeys[name]}`),
    };

    // Merge defaultArgs with constructorArgs
    const args = { ...defaultArgs, ...constructorArgs };
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name]);

    log("Deploying...", `deployParentPool, ${deployer}`, name);

    const { publicClient: viemPublicClient } = getFallbackClients(conceroNetworks[name]);
    const gasPrice = await viemPublicClient.getGasPrice();

    const deployParentPool = (await deploy("ParentPool", {
      from: deployer,
      args: [
        args.parentProxyAddress,
        args.parentPoolCLFCLA,
        args.automationForwarder ?? zeroAddress,
        args.linkToken,
        args.ccipRouter,
        args.usdc,
        args.lpToken,
        args.infraProxyAddress,
        args.clfRouter,
        args.owner,
        args.poolMessengers,
      ],
      log: true,
      autoMine: true,
      maxFeePerGas,
      maxPriorityFeePerGas,
    })) as Deployment;

    if (live) {
      log(`Deployed at: ${deployParentPool.address}`, "deployParentPool", name);
      updateEnvVariable(`PARENT_POOL_${networkEnvKeys[name]}`, deployParentPool.address, `deployments.${networkType}`);
    }
  };

export default deployParentPool;
deployParentPool.tags = ["ParentPool"];

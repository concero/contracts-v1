import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils";
import { poolMessengers } from "../constants";
import { getGasParameters } from "../utils/getGasPrice";

interface ConstructorArgs {
  conceroProxyAddress?: string;
  parentProxyAddress?: string;
  childProxyAddress?: string;
  linkToken?: string;
  ccipRouter?: string;
  chainSelector?: number;
  usdc?: string;
  owner?: string;
  messengers?: string[];
}

const deployChildPool: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;

    const { linkToken, ccipRouter, type } = conceroNetworks[name];

    const defaultArgs = {
      conceroProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
      childProxyAddress: getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`),
      linkToken: linkToken,
      ccipRouter: ccipRouter,
      usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
      owner: deployer,
      poolMessengers,
    };

    // Merge defaultArgs with constructorArgs
    const args = { ...defaultArgs, ...constructorArgs };
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name]);

    log("Deploying...", "deployChildPool", name);

    const deployChildPool = (await deploy("ChildPool", {
      from: deployer,
      args: [
        args.conceroProxyAddress,
        args.childProxyAddress,
        args.linkToken,
        args.ccipRouter,
        args.usdc,
        args.owner,
        args.poolMessengers,
      ],
      log: true,
      autoMine: true,
      maxFeePerGas,
      maxPriorityFeePerGas,
    })) as Deployment;

    if (live) {
      log(`Deployed at: ${deployChildPool.address}`, "deployConceroChildPool", name);
      updateEnvVariable(`CHILD_POOL_${networkEnvKeys[name]}`, deployChildPool.address, `deployments.${type}`);
    }
  };

export default deployChildPool;
deployChildPool.tags = ["ChildPool"];

import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployChildPool from "../../../deploy/ChildPool";
import { setChildPoolProxyVariables } from "./setChildPoolProxyVariables";
import deployProxyAdmin from "../../../deploy/ConceroProxyAdmin";
import deployTransparentProxy from "../../../deploy/TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
import { compileContracts, verifyVariables } from "../../../utils";
import { conceroNetworks, networkTypes, ProxyEnum } from "../../../constants";

task("deploy-child-pool", "Deploy the pool")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("deployimplementation", "Deploy the implementation")
  .addFlag("setvars", "Set the contract variables")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    compileContracts({ quiet: true });

    const networkType = conceroNetworks[hre.network.name].type;
    if (networkType == networkTypes.mainnet) {
      await verifyVariables();
    }

    if (taskArgs.deployproxy) {
      await deployProxyAdmin(hre, ProxyEnum.childPoolProxy);
      await deployTransparentProxy(hre, ProxyEnum.childPoolProxy);
    }

    if (taskArgs.deployimplementation) {
      await deployChildPool(hre);
      await upgradeProxyImplementation(hre, ProxyEnum.childPoolProxy, false);
    }

    if (taskArgs.setvars) {
      await setChildPoolProxyVariables(hre);
    }
  });

export default {};

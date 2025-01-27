import { task } from "hardhat/config";
import deployPauseDummy from "../../deploy/PauseDummy";

task("deploy-pause-dummy", "Funds the contract with CCIPBNM tokens").setAction(async taskArgs => {
  const hre = require("hardhat");
  const { name, live } = hre.network;
  await deployPauseDummy(hre);
});

export default {};

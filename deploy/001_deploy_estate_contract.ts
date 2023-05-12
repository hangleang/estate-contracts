import { DeployFunction } from "hardhat-deploy/types";

import { VERIFICATION_BLOCK_CONFIRMATIONS } from "../utils/constants";

const func: DeployFunction = async ({ getNamedAccounts, deployments, network, run }) => {
  const { deploy, log } = deployments;
  const { deployer, feeCollector } = await getNamedAccounts();
  const isDev = !network.live;
  const waitConfirmations = network.live ? VERIFICATION_BLOCK_CONFIRMATIONS : undefined;

  if (isDev) {
    // deploy mocks/test contract
  } else {
    // set external contract address
  }

  // the following will only deploy "EstateContract" if the contract was never deployed or if the code changed since last deployment
  const args = ["Test Estate Contract", "TEC", "1.0.0", feeCollector, 500];
  const estate = await deploy("EstateContract", {
    from: deployer,
    args,
    log: true,
    autoMine: isDev,
    waitConfirmations,
  });

  // Verify the deployment
  if (!isDev) {
    log("Verifying...");
    await run("verify:verify", {
      address: estate.address,
      constructorArguments: args,
    });
  }
};

export default func;
func.tags = ["all", "EstateContract"];
func.dependencies = []; // this contains dependencies tags need to execute before deploy this contract

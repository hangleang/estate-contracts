import { Contract } from "ethers";
import { deployments, ethers } from "hardhat";

export const getContract = async <T extends Contract>(name: string): Promise<T> => {
  return (await ethers.getContractAt(name, (await deployments.get(name)).address)) as T;
};

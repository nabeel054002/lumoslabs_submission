const { ethers } = require("hardhat");
require("dotenv").config({ path: ".env" });

async function main() {
    const CT = await ethers.getContractFactory("CryptoToken");
    const deployedMutualFund = await CT.deploy();
    //the time that is to be actually implemented in the second arg is 1 day = 60*60*24, for now, i am keeping it as 2 minutes, hence it will be like 14 minutes before a proposal is acted upone
    await deployedMutualFund.deployed();
    console.log("Address of AMF:", deployedMutualFund.address);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

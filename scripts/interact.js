
const { ethers } = require("hardhat");
require("dotenv").config({ path: ".env" });
const {UNISWAP_ROUTER, MUTUALFUND, MUTUALFUND_ABI} = require("../constants");
const {BigNumber} = require("ethers");

async function main() {
    
    const contract = await ethers.getContractAt("MutualFundV2", MUTUALFUND);
    const portfolio = await contract.Portfolio(0);
    console.log(portfolio);

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

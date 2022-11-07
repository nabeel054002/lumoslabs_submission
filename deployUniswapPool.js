const {ethers} = require("ethers");
const axios = require("axios");
require('dotenv').config()

const MATIC_ADDRESS="0x0000000000000000000000000000000000001010";
const CT_ADDRESS="0xB2E82ecd63861BBc39D7A95211112EB464d5CD25";
const UNISWAP_V3_FACTORY="0x1f98431c8ad98523631ae4a59f267346ea31f984";
const MUMBAI_PROVIDER=new ethers.providers.JsonRpcProvider(process.env.QUICKNODE_HTTP_URL);
const WALLET_ADDRESS = process.env.WALLET_ADDRESS;
const WALLET_PRIVATE_KEY=process.env.PRIVATE_KEY;

const wallet = new ethers.Wallet(WALLET_PRIVATE_KEY);
const connectedWallet = wallet.connect(MUMBAI_PROVIDER);

async function main(){
    const apiKey = 'YSFTZMCRI88STDFR4BWJD3EG5R8H7SNR4Z';
    const url = `https://api.etherscan.io/api?module=contract&action=getabi&address=${UNISWAP_V3_FACTORY}&apikey=${apiKey}`;
    const res = await axios.get(url);
    const abi = JSON.parse(res.data.result);
    const factoryContract = new ethers.Contract(UNISWAP_V3_FACTORY, abi, MUMBAI_PROVIDER);
    const tx = await factoryContract.connect(connectedWallet).createPool(
        MATIC_ADDRESS, 
        CT_ADDRESS,
        1500
    )
    const reciept = tx.wait();
    const newPoolAddress = await factoryContract.getPool(MATIC_ADDRESS,CT_ADDRESS, 1500);
    console.log("Address of pool is", newPoolAddress);
}
main();
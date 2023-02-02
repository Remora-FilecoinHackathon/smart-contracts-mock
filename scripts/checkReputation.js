const axios = require("axios");
const ethers = require("hardhat").ethers;

const ENDPOINT_ADDRESS = "https://api.hyperspace.node.glif.io/rpc/v1";

async function callRpc(method, params) {
  const res = await axios.post(ENDPOINT_ADDRESS, {
    jsonrpc: "2.0",
    method: method,
    params: params,
    id: 1,
  });
  return res.data;
}

async function main(address) {
  try {
    const LENDER_MANAGER_ADDRESS = "0x469f613A055E4b763BAfA904CeC7C74984C79B4b";

    var priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    const LenderManager = await ethers.getContractFactory("LenderManager");
    const lenderManager = LenderManager.attach(LENDER_MANAGER_ADDRESS);
    lenderManager.on("CheckReputation", async function (id, address) {
      let tx = await lenderManager.receiveReputationScore(id, 2, {
        gasLimit: 1000000000,
        maxPriorityFeePerGas: priorityFee.result,
      });
      await tx.wait();
    });
  } catch (error) {
    console.log(error);
  }
}

// In Lambda, this address will be passed via the event listener
main("f01662887");

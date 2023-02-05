const axios = require("axios");
const ethers = require("ethers");
const fs = require('fs');
//const LendingManagerABI = require('./LenderManager.json');
const LendingManagerABI = require('./LenderManager.json');

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

// async function getData(apiUrl, params) {
//   try {
//       const response = await axios.get(apiUrl + params);
//       return response.data['miners'];
//   } catch (error) {
//       return error.message;
//   }
// }

// async function determineIfMinerIsReputable(jsonData) {
//   var minerIsReputable = false;
//   var minerReputation = jsonData[0].score;
//   var minerReachable = jsonData[0].reachability;

//   if (minerReputation > 95 && minerReachable === 'reachable') {
//       minerIsReputable = true;
//       return minerIsReputable;
//   }
//   else {
//       return minerIsReputable;
//   }
// }

async function main(address) {
  try {
    const LENDER_MANAGER_ADDRESS = "0xbCD7942E4016584b8a285BC2d8914c3B3d857f19";
    const PRIVATE_KEY = process.env.PRIVATE_KEY_BORROWER;
    const WALLET = new ethers.Wallet(PRIVATE_KEY);
    const PROVIDER = new ethers.providers.JsonRpcProvider(ENDPOINT_ADDRESS);
    const SIGNER = WALLET.connect(PROVIDER);
    const LenderManager = new ethers.Contract(LENDER_MANAGER_ADDRESS, LendingManagerABI, SIGNER);
    const lenderManager = LenderManager.attach(LENDER_MANAGER_ADDRESS);
    var priorityFee = await callRpc("eth_maxPriorityFeePerGas");
    await lenderManager.checkReputation(address, {
      maxPriorityFeePerGas: priorityFee.result,
    });

    // lenderManager.on("CheckReputation", async function (id, address) {
    //   let tx = await lenderManager.receiveReputationScore(id, 2, {
    //     gasLimit: 1000000000,
    //     maxPriorityFeePerGas: priorityFee.result,
    //   });
    //   await tx.wait();
    // });
  } catch (error) {
    console.log(error);
  }
}

// In Lambda, this address will be passed via the event listener
main("0x73CF998AF5dF38c849A58fc3d40142e6574c27AC");
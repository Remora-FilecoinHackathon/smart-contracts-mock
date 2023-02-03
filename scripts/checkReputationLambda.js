const axios = require("axios");
const ethers = require("ethers");
const fs = require('fs');
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

async function main(address) {
	  try {
		      const LENDER_MANAGER_ADDRESS = process.env.LENDER_MANAGER;
		      const PRIVATE_KEY = process.env.PRIVATE_KEY;
		      const WALLET = new ethers.Wallet(PRIVATE_KEY);
		      const PROVIDER = new ethers.providers.JsonRpcProvider(ENDPOINT_ADDRESS);
		      const SIGNER = WALLET.connect(PROVIDER);
		      const LenderManager = new ethers.Contract(LENDER_MANAGER_ADDRESS, LendingManagerABI, SIGNER);
		      const lenderManager = LenderManager.attach(LENDER_MANAGER_ADDRESS);
		      console.log("GETTING GAS PRICE");
		      var priorityFee = await callRpc("eth_maxPriorityFeePerGas");
		      console.log("CHECKING REPUTATION");
		      await lenderManager.checkReputation(address, {
			            maxPriorityFeePerGas: priorityFee.result,
			          });
			  console.log("WAITING FOR CHECK REPUTATION");
		      await lenderManager.on("CheckReputation", async function (id, address) {
			            await lenderManager.receiveReputationScore(id, 2, {
					            gasLimit: 1000000000,
					            maxPriorityFeePerGas: priorityFee.result,
					          });
			            console.log("REPUTATION INFO SENT");
			          });
		    } catch (error) {
			        console.log(error);
			      }
}

exports.handler = (event) => {
	const message = event.Records[0].body;
	console.log(`Received message: ${message}`);
	main(message);
};
       

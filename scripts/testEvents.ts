import { ethers } from "hardhat";
import axios from "axios";
import { SQS } from "aws-sdk";

const ENDPOINT_ADDRESS = "https://api.hyperspace.node.glif.io/rpc/v1";

async function callRpc(method: string, params?: any) {
  const res = await axios.post(ENDPOINT_ADDRESS, {
    jsonrpc: "2.0",
    method: method,
    params: params,
    id: 1,
  });
  return res.data;
}

async function sendMessage(id, response) {
  const sqs = new SQS({ region: 'us-west-2' });
  const queueUrl = "https://sqs.us-west-2.amazonaws.com/130922966848/remora-events";
  const params = {
    MessageBody: JSON.stringify({ id: id, address: response }),
    QueueUrl: queueUrl,
  };
  const result = await sqs.sendMessage(params).promise();
  console.log(result);
}

async function main() {
  // NEW ADDRESS: 0xaE7eD725f5053471DB2Fc7254dBB2766615f7064
  const LENDER_MANAGER_ADDRESS = "0xaE7eD725f5053471DB2Fc7254dBB2766615f7064";
  const LenderManager = await ethers.getContractFactory("LenderManager");
  const lenderManager = LenderManager.attach(LENDER_MANAGER_ADDRESS);
  const processedIds = new Set();

  lenderManager.on(
    "CheckReputation",
    async function (id, response) {
      id = parseInt(id._hex, 16);
      console.log("**** EVENT RECEIVED ****");
      console.log(JSON.stringify({ id: id, address: response }))

      // check if the id has already been processed
      if (processedIds.has(id)) {
        return;
      }
      
      // add the id to the set of processed ids
      processedIds.add(id);
      console.log("PROCESSED IDS SET");
      console.log(processedIds);

      setTimeout(function() {
        for (const currentId of processedIds) {
          console.log("CURRENT ID");
          console.log(currentId);
          console.log(response);
          // Not sure the line below is good enough on response, might not match in prod
          sendMessage(currentId, response);
          processedIds.delete(currentId);
        }
      }, 5000);
    }
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

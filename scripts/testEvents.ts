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

async function deploy() {}

async function main() {
  const MINER_ADDRESS =
    "t3wj7cikpzptshfuwqleehoytar2wcvom42q6io7lopbl2yp2kb2yh3ymxovsd5ccrgm36ckeibzjl3s27pzuq";
  const ORACLE_ADDRESS = "0xbd6E4e826D26A8C984C1baF057D6E62cC245645D";
  const LENDER_MANAGER_ADDRESS = "0xbCD7942E4016584b8a285BC2d8914c3B3d857f19";
  
  var priorityFee = await callRpc("eth_maxPriorityFeePerGas");
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
    });


    // LEAVING OFF HERE
    // Don't know for sure that the timeout is the best way to go
    // 
    setTimeout(async function() {
      // This now needs to remove an id from processedIds once the message is sent 
      const sqs = new SQS({ region: 'us-west-2' });
      const queueUrl = "https://sqs.us-west-2.amazonaws.com/130922966848/fil-reputation";
      const params = {
        MessageBody: JSON.stringify({ id: parseInt(id._hex, 16), response: parseInt(response._hex, 16) }),
        QueueUrl: queueUrl,
      };
      const result = await sqs.sendMessage(params).promise();
      console.log(result);
    }, 5000);


    

  // lenderManager.on(
  //   "ReputationReceived",
  //   async function (id, response, miner) {
  //     console.log("**** EVENT RECEIVED ****");

  //     const sqs = new SQS({ region: 'us-west-2' });
  //     const queueUrl = "https://sqs.us-west-2.amazonaws.com/130922966848/fil-reputation";
  //     const params = {
  //       MessageBody: JSON.stringify({ id: parseInt(id._hex, 16), response: parseInt(response._hex, 16), miner: miner }),
  //       QueueUrl: queueUrl,
  //     };
  //     const result = await sqs.sendMessage(params).promise();
  //     console.log(result);
  //   }
  // );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

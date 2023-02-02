import { ethers } from "hardhat";
import axios from "axios";
import { addressAsBytes } from "./utils/parseAddress";
import {
  HttpJsonRpcConnector,
  LotusWalletProvider,
  LotusClient,
} from "filecoin.js";
import * as dotenv from "dotenv";
dotenv.config();

const ENDPOINT_ADDRESS = "https://api.hyperspace.node.glif.io/rpc/v1";
const LOTUS_HTTP_RPC_ENDPOINT = "https://100.20.82.125:1234";

const ORACLE_ADDRESS = "0xc2b60CfFe4f20b2046C951CDEB459aF897cff571";
const MINER_ADDRESS =
  "t3wj7cikpzptshfuwqleehoytar2wcvom42q6io7lopbl2yp2kb2yh3ymxovsd5ccrgm36ckeibzjl3s27pzuq";

async function callRpc(method: string, params?: any) {
  const res = await axios.post(ENDPOINT_ADDRESS, {
    jsonrpc: "2.0",
    method: method,
    params: params,
    id: 1,
  });
  return res.data;
}

async function main() {
  const [owner, otherAccount, oracleAccount] = await ethers.getSigners();

  var priorityFee = await callRpc("eth_maxPriorityFeePerGas");

  const LenderManager = await ethers.getContractFactory("LenderManager");
  const lenderManager = await LenderManager.deploy(ORACLE_ADDRESS, {
    maxPriorityFeePerGas: priorityFee.result,
  });
  await lenderManager.deployed();
  console.log(`Deployed to ${lenderManager.address}`);

  priorityFee = await callRpc("eth_maxPriorityFeePerGas");
  let tx = await lenderManager.connect(otherAccount).deployMockMinerActor({
    maxPriorityFeePerGas: priorityFee.result,
  });
  await tx.wait();

  priorityFee = await callRpc("eth_maxPriorityFeePerGas");
  const MINER_ADDRESS = await lenderManager.ownerToMinerActor(
    otherAccount.address,
    {
      maxPriorityFeePerGas: priorityFee.result,
    }
  );
  console.log(`MINER_ADDRESS is ${MINER_ADDRESS}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

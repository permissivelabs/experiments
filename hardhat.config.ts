import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox"

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
      hardhat: {
      },
    },
    solidity: {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    },
    paths: {
      sources: "./contracts",
      tests: "./test",
      cache: "./cache",
      artifacts: "./artifacts"
    },
    mocha: {
      timeout: 40000
    }
  }

export default config
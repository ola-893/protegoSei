require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
        details: {
          yul: true,
          yulDetails: {
            stackAllocation: true,
            optimizerSteps: "dhfoDgvulfnTUtnIf"
          }
        }
      },
      viaIR: true, // Enable IR-based compilation for better optimization
    },
  },

networks: {
  seimainnet: { 
    url: "https://evm-rpc.sei-apis.com",
    chainId: 1329, 
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    gasPrice: 2000000000, 
    gas: "auto",
    timeout: 60000,
    confirmations: 1,
  },
  
  seitestnet: { 
    url: "https://evm-rpc-testnet.sei-apis.com",
    chainId: 1328, 
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    gasPrice: 2000000000,
    gas: "auto", 
    timeout: 60000,
    confirmations: 1,
  },
  
  localhost: {
    url: "http://127.0.0.1:8545",
    chainId: 31337,
    accounts: {
      mnemonic: "test test test test test test test test test test test junk",
      count: 20,
      accountsBalance: "10000000000000000000000"
    },
    mining: {
      auto: true,
      interval: 600,
    },
    gasPrice: "auto",
    gas: "auto",
  }
},
  
  etherscan: {
  apiKey: {
    seimainnet: process.env.SEI_API_KEY || "your-sei-explorer-api-key", // lowercase
    seitestnet: process.env.SEI_TESTNET_API_KEY || "your-sei-testnet-api-key" // lowercase
  },
  customChains: [
    {
      network: "seimainnet", // lowercase
      chainId: 1329,
      urls: {
        apiURL: "https://seistream.app/api",
        browserURL: "https://seistream.app"
      }
    },
    {
      network: "seitestnet", // lowercase
      chainId: 1328, // Updated chain ID
      urls: {
        apiURL: "https://seistream.app/testnet/api",
        browserURL: "https://seistream.app/testnet"
      }
    }
  ]
},
  
  // Gas reporter configuration
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 0.1, // Sei's low gas costs
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    token: "SEI",
    gasPriceApi: "https://api.sei.io/gas-price", // Custom for Sei if available
  },
  
  // Mocha test configuration  
  mocha: {
    timeout: 120000, // 2 minutes for comprehensive tests
    reporter: "spec",
    slow: 5000,
  },
  
  // Contract size limits
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  
  // Path configuration
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
    deploy: "./deploy",
    deployments: "./deployments",
  },
  
  // External contract dependencies
  external: {
    contracts: [
      {
        artifacts: "node_modules/@openzeppelin/contracts",
      },
    ],
  },
  
  // Compiler warnings suppression
  warnings: {
    "*": {
      "contracts/mocks/**/*": "off",
      "default": "error"
    }
  }
};

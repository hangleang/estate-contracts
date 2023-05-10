import type { HardhatUserConfig } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "solidity-docgen";

import "./scripts/accounts";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

const testJunk = "test ".repeat(11) + "junk";
const mnemonic: string = process.env.MNEMONIC || testJunk;
const privateKey: string | undefined = process.env.PRIVATE_KEY;
const infuraApiKey: string = process.env.INFURA_API_KEY || "";

export const chainIds = {
  "arbitrum-mainnet": 42161,
  "aurora-mainnet": 1313161554,
  "aurora-testnet": 1313161555,
  avalanche: 43114,
  bsc: 56,
  hardhat: 31337,
  "fantom-opera": 250,
  "fantom-testnet": 4002,
  mainnet: 1,
  "optimism-mainnet": 10,
  "polygon-mainnet": 137,
  "polygon-mumbai": 80001,
  goerli: 5,
  localhost: 1337,
};

function getChainConfig(chain: keyof typeof chainIds): NetworkUserConfig {
  let jsonRpcUrl: string;
  switch (chain) {
    case "avalanche":
      jsonRpcUrl = "https://api.avax.network/ext/bc/C/rpc";
      break;
    case "bsc":
      jsonRpcUrl = "https://bsc-dataseed1.binance.org";
      break;
    case "fantom-opera":
      jsonRpcUrl = "https://rpc.ankr.com/fantom";
      break;
    case "fantom-testnet":
      jsonRpcUrl = "https://rpc.testnet.fantom.network";
      break;
    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  }

  const chainConfig: NetworkUserConfig = {
    chainId: chainIds[chain],
    url: jsonRpcUrl,
    live: true,
  };

  if (privateKey)
    return {
      ...chainConfig,
      accounts: [privateKey],
    };

  return {
    ...chainConfig,
    accounts: {
      count: 10,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  docgen: {
    exclude: ["test", "mocks"],
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      avalanche: process.env.SNOWTRACE_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      opera: process.env.FTMSCAN_API_KEY || "",
      ftmTestnet: process.env.FTMSCAN_API_KEY || "",
      aurora: process.env.AURORASCAN_API_KEY || "",
      auroraTestnet: process.env.AURORASCAN_API_KEY || "",
    },
  },
  // `external` field allows to specify paths for external artifacts or deployments for external contract interaction
  external: {
    contracts: [],
    deployments: {},
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true" ? true : false,
    currency: "USD",
    coinmarketcap: process.env.COIN_MARKETCAP_API_KEY,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      chainId: chainIds.hardhat,
      live: false,
    },
    localhost: {
      chainId: chainIds.localhost,
      accounts: { mnemonic: testJunk },
      live: false,
    },
    arbitrum: getChainConfig("arbitrum-mainnet"),
    avalanche: getChainConfig("avalanche"),
    bsc: getChainConfig("bsc"),
    mainnet: getChainConfig("mainnet"),
    optimism: getChainConfig("optimism-mainnet"),
    "polygon-mainnet": getChainConfig("polygon-mainnet"),
    "polygon-mumbai": getChainConfig("polygon-mumbai"),
    goerli: getChainConfig("goerli"),
    "fantom-opera": getChainConfig("fantom-opera"),
    "fantom-testnet": getChainConfig("fantom-testnet"),
    "aurora-mainnet": getChainConfig("aurora-mainnet"),
    "aurora-testnet": getChainConfig("aurora-testnet"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
    deploy: "./deploy",
    deployments: "./deployments",
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      [chainIds.mainnet]: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    feeCollector: {
      default: 1,
    },
  },
  solidity: {
    version: "0.8.15",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/hardhat-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  mocha: {
    timeout: 200000, // 200 seconds max for running tests
  },
};

export default config;

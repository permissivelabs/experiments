import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import { config as dConfig } from 'dotenv';

dConfig();

const config: HardhatUserConfig = {
	defaultNetwork: 'hardhat',
	networks: {
		hardhat: {},
		mumbai: {
			url: process.env.RPC,
			accounts: [
				process.env.PRIVATE_KEY as string,
				process.env.PRIVATE_KEY2 as string,
			],
		},
	},
	solidity: {
		version: '0.8.19',
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts',
	},
	mocha: {
		timeout: 40000,
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN,
	},
};

export default config;

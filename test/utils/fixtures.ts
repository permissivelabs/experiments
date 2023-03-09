import { Contract } from 'ethers';
import { keccak256 } from 'ethers/lib/utils';
import { ethers } from 'hardhat';

export const generateCorrectPermissionAndOperation = (account: Contract) => {
	const permission = {
		operator: '0x429952c8d27F515011d623dFC9038152af52C5a8',
		to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
		selector: '0xb7760c8f',
		maxValue: 5,
		maxFee: 5,
		paymaster: '0x0000000000000000000000000000000000000000',
		expires_at_unix: 1709933133,
		expires_at_block: 0,
	};
	const operation = {
		sender: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
		nonce: 0,
		initCode: [],
		callData: account.interface.encodeFunctionData('execute', [
			'0x0576a174D229E3cFA37253523E645A78A0C91B57',
			5,
			'0xb7760c8f' +
				ethers.utils.defaultAbiCoder
					.encode(
						['uint256', 'address'],
						[100, '0x0576a174D229E3cFA37253523E645A78A0C91B57']
					)
					.slice(2),
			permission,
			[],
		]),
		callGasLimit: 667,
		verificationGasLimit: 668,
		preVerificationGas: 669,
		maxFeePerGas: 700,
		maxPriorityFeePerGas: 701,
		paymasterAndData: '0x00',
		signature: '0x00',
	};

	return {
		operation,
		permission,
	};
};

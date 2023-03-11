import { Contract } from 'ethers';
import { defaultAbiCoder, keccak256 } from 'ethers/lib/utils';
import { ethers } from 'hardhat';
import { Permission, ZPermission } from './types';
import { MerkleTree } from 'merkletreejs';

export const permissionsSample = (): Permission[] => {
	return [
		{
			operator: '0x429952c8d27F515011d623dFC9038152af52C5a8',
			to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
			selector: '0xa9059cbb', // erc20 transfer
			maxValue: 5,
			maxFee: 5,
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		},
		{
			operator: '0x429952c8d27F515011d623dFC9038152af52C5a8',
			to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
			selector: '0xab790ba3', // erc721 transfer
			maxValue: 5,
			maxFee: 5,
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		},
		{
			operator: '0x429952c8d27F515011d623dFC9038152af52C5a8',
			to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
			selector: '0x022c0d9f', // swap uniswap
			maxValue: 5,
			maxFee: 5,
			paymaster: '0x0000000000000000000000000000000000000000',
			expiresAtUnix: 1709933133,
			expiresAtBlock: 0,
		},
	].map((p) => ZPermission.parse(p));
};

export const hashPermission = (permission: Permission): string => {
	return keccak256(
		defaultAbiCoder.encode(
			[
				'address',
				'address',
				'bytes4',
				'uint256',
				'uint256',
				'address',
				'uint256',
				'uint256',
			],
			Object.values(permission)
		)
	);
};

export const computerPermissionMerkleTree = (permissions: Permission[]) => {
	const leaves = permissions.map((p) => hashPermission(p));
	const tree = new MerkleTree(leaves, keccak256, {
		sortLeaves: true,
	});
	const root = tree.getRoot().toString('hex');
	return {
		tree,
		root,
	};
};

export const generateCorrectPermissionAndOperation = (account: Contract) => {
	const permission = ZPermission.parse({
		operator: '0x429952c8d27F515011d623dFC9038152af52C5a8',
		to: '0x0576a174D229E3cFA37253523E645A78A0C91B57',
		selector: '0xb7760c8f',
		maxValue: 5,
		maxFee: 5,
		paymaster: '0x0000000000000000000000000000000000000000',
		expiresAtUnix: 1709933133,
		expiresAtBlock: 0,
	});
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
			'0x0000000000000000000000000000000000000000000000000000000000000000',
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

import { expect, should } from 'chai';
import { randomBytes } from 'ethers/lib/utils';
import { Wallet } from 'ethers/lib/index';
import hre, { ethers, userConfig } from 'hardhat';
import { ENTRYPOINT } from './utils/constants';
import {
	generateCorrectOperation,
	hashPermission,
	permissionsSample,
	setupAccount,
	computerPermissionMerkleTree,
} from './utils/fixtures';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { CustomEntryPoint, PermissiveAccount } from '../typechain-types';
import { UserOperationStruct } from '@account-abstraction/contracts';

describe('setOperatorPermissions', () => {
	it('should update permission hash, update fee and value and emit event', async () => {
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(ENTRYPOINT);
		const [operator, merkleRoot] = [
			Wallet.createRandom().address,
			randomBytes(32),
		];
		const tx = account.setOperatorPermissions(operator, merkleRoot, 5, 8);
		await expect(tx).not.reverted;
		await expect(tx)
			.emit(account, 'OperatorMutated')
			.withArgs(
				operator,
				'0x0000000000000000000000000000000000000000000000000000000000000000',
				merkleRoot
			);
	});
});

describe('Entrpoint', () => {
	it('deploy entrypoint', async () => {
		const Entrypoint = await hre.ethers.getContractFactory('CustomEntryPoint');
		await expect(Entrypoint.deploy()).not.reverted;
	});
});

describe('validateUserOp', () => {
	let owner: SignerWithAddress, operator: SignerWithAddress;
	let entrypoint: CustomEntryPoint;
	let account: PermissiveAccount;
	let operation: UserOperationStruct;

	before(async () => {
		const Entrypoint = await hre.ethers.getContractFactory('CustomEntryPoint');
		entrypoint = await Entrypoint.deploy();
	});

	beforeEach(async () => {
		const signers = await ethers.getSigners();
		owner = signers[0];
		operator = signers[1];
		account = await setupAccount(entrypoint.address, operator.address, owner);
		operation = generateCorrectOperation(account, operator.address);
		operation.sender = account.address;
		const opHash = await entrypoint.getUserOpHash(operation);
		operation.signature = await operator.signMessage(
			ethers.utils.arrayify(opHash)
		);
	});

	it('should transfer usdc', async () => {
		const Token = await ethers.getContractFactory('Token');
		const usdc = await Token.deploy('USD Coin', 'USDC');
		await usdc.mint();
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(entrypoint.address);
		await usdc.transfer(account.address, ethers.utils.parseEther('50'));
		const merkleRoot =
			'0x' +
			computerPermissionMerkleTree([
				{
					operator: operator.address,
					to: usdc.address,
					selector: Token.interface.getSighash('transfer'),
					paymaster: '0x0000000000000000000000000000000000000000',
					expiresAtUnix: 1709933133,
					expiresAtBlock: 0,
				},
			]).root;
		await account.setOperatorPermissions(
			operator.address,
			merkleRoot,
			ethers.utils.parseEther('0.5'),
			ethers.utils.parseEther('0.5')
		);
		await owner.sendTransaction({
			value: ethers.utils.parseEther('1'),
			to: account.address,
		});
		operation = generateCorrectOperation(account, operator.address);
		operation.callData = account.interface.encodeFunctionData('execute', [
			usdc.address,
			0,
			usdc.interface.encodeFunctionData('transfer', [
				operator.address,
				ethers.utils.parseEther('10'),
			]),
			{
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			},
			computerPermissionMerkleTree([
				{
					operator: operator.address,
					to: usdc.address,
					selector: Token.interface.getSighash('transfer'),
					paymaster: '0x0000000000000000000000000000000000000000',
					expiresAtUnix: 1709933133,
					expiresAtBlock: 0,
				},
			])
				.tree.getProof(
					hashPermission({
						operator: operator.address,
						to: usdc.address,
						selector: Token.interface.getSighash('transfer'),
						paymaster: '0x0000000000000000000000000000000000000000',
						expiresAtUnix: 1709933133,
						expiresAtBlock: 0,
					})
				)
				.map((e) => `0x${e.data.toString('hex')}`),
		]);
		operation.sender = account.address;
		const opHash = await entrypoint.getUserOpHash(operation);
		operation.signature = await operator.signMessage(
			ethers.utils.arrayify(opHash)
		);
		await entrypoint.handleOps([operation], account.address);
		console.log(
			usdc.interface.encodeFunctionData('transfer', [
				operator.address,
				ethers.utils.parseEther('10'),
			])
		);
		console.log(
			'Owner:',
			ethers.utils.formatEther(await usdc.balanceOf(owner.address))
		);
		console.log(
			'Account:',
			ethers.utils.formatEther(await usdc.balanceOf(owner.address))
		);
		console.log(
			'Operator:',
			ethers.utils.formatEther(await usdc.balanceOf(operator.address))
		);
		await account.execute(
			usdc.address,
			0,
			usdc.interface.encodeFunctionData('transfer', [
				operator.address,
				ethers.utils.parseEther('10'),
			]),
			{
				operator: operator.address,
				to: usdc.address,
				selector: Token.interface.getSighash('transfer'),
				paymaster: '0x0000000000000000000000000000000000000000',
				expiresAtUnix: 1709933133,
				expiresAtBlock: 0,
			},
			[]
		);
		console.log(
			'Owner:',
			ethers.utils.formatEther(await usdc.balanceOf(owner.address))
		);
		console.log(
			'Account:',
			ethers.utils.formatEther(await usdc.balanceOf(owner.address))
		);
		console.log(
			'Operator:',
			ethers.utils.formatEther(await usdc.balanceOf(operator.address))
		);
	});

	// it('should validate', async () => {
	// 	await entrypoint.handleOps([operation], account.address);
	// });

	// it('should refuse because invalid operator', async () => {});
});

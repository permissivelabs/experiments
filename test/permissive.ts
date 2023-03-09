import { expect } from 'chai';
import { defaultAbiCoder } from 'ethers/lib/utils';
import hre, { ethers } from 'hardhat';
import { generateCorrectPermissionAndOperation } from './utils/fixtures';

describe('_validatePermission', () => {
	it('should refuse for InvalidTo', async () => {
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(
			'0x0576a174D229E3cFA37253523E645A78A0C91B57'
		);
		const { permission, operation } =
			generateCorrectPermissionAndOperation(account);
		permission.to = ethers.Wallet.createRandom().address;
		await expect(account._validatePermission(operation, permission))
			.to.be.revertedWithCustomError(account, 'InvalidTo')
			.withArgs('0x0576a174D229E3cFA37253523E645A78A0C91B57', permission.to);
	});
	it('should refuse for ExceededValue', async () => {
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(
			'0x0576a174D229E3cFA37253523E645A78A0C91B57'
		);
		const { permission, operation } =
			generateCorrectPermissionAndOperation(account);
		permission.maxValue = 2;
		await expect(account._validatePermission(operation, permission))
			.to.be.revertedWithCustomError(account, 'ExceededValue')
			.withArgs(5, permission.maxValue);
	});
	it('should refuse for InvalidSelector', async () => {
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(
			'0x0576a174D229E3cFA37253523E645A78A0C91B57'
		);
		const { permission, operation } =
			generateCorrectPermissionAndOperation(account);
		operation.callData = account.interface.encodeFunctionData('execute', [
			'0x0576a174D229E3cFA37253523E645A78A0C91B57',
			5,
			'0x12345678' +
				ethers.utils.defaultAbiCoder
					.encode(
						['uint256', 'address'],
						[100, '0x0576a174D229E3cFA37253523E645A78A0C91B57']
					)
					.slice(2),
			permission,
			[],
		]);
		await expect(
			account._validatePermission(operation, permission)
		).to.be.revertedWithCustomError(account, 'InvalidSelector');
	});
	it('should refuse for InvalidSelector', async () => {
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(
			'0x0576a174D229E3cFA37253523E645A78A0C91B57'
		);
		const { permission, operation } =
			generateCorrectPermissionAndOperation(account);
		operation.callData = account.interface.encodeFunctionData('execute', [
			'0x0576a174D229E3cFA37253523E645A78A0C91B57',
			5,
			'0x12345678' +
				ethers.utils.defaultAbiCoder
					.encode(
						['uint256', 'address'],
						[100, '0x0576a174D229E3cFA37253523E645A78A0C91B57']
					)
					.slice(2),
			permission,
			[],
		]);
		await expect(
			account._validatePermission(operation, permission)
		).to.be.revertedWithCustomError(account, 'InvalidSelector');
	});
	it('should refuse for InvalidPaymaster', async () => {
		const Permissive = await hre.ethers.getContractFactory('PermissiveAccount');
		const account = await Permissive.deploy(
			'0x0576a174D229E3cFA37253523E645A78A0C91B57'
		);
		const { permission, operation } =
			generateCorrectPermissionAndOperation(account);
		operation.paymasterAndData = defaultAbiCoder.encode(['address'], ['0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5'])
		permission.maxFee = 0;
		await expect(account._validatePermission(operation, permission))
			.to.be.revertedWithCustomError(account, 'InvalidPaymaster')
			.withArgs(
				permission.paymaster,
				'0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5'
			);
	});
});

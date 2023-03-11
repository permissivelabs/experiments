import { expect, should } from 'chai';
import { randomBytes } from 'ethers/lib/utils';
import { Wallet } from 'ethers/lib/index';
import hre, { ethers } from 'hardhat';
import { ENTRYPOINT } from './utils/constants';
import { BaseAccountAPI } from '@account-abstraction/sdk/dist/src/BaseAccountAPI';
import {
	generateCorrectOperation,
	hashPermission,
	permissionsSample,
	setupAccount,
} from './utils/fixtures';
import { SimpleAccountAPI } from '@account-abstraction/sdk';

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
	it('should validate', async () => {
		const signers = await ethers.getSigners();
		const owner = signers[0];
		const operator = signers[1];
		const Entrypoint = await hre.ethers.getContractFactory('CustomEntryPoint');
		const entrypoint = await Entrypoint.deploy();
		const account = await setupAccount(
			entrypoint.address,
			operator.address,
			owner
		);
		const operation = generateCorrectOperation(account, operator.address);
		operation.sender = account.address;
		const opHash = await entrypoint.getUserOpHash(operation);
		operation.signature = operator.signMessage(ethers.utils.arrayify(opHash));
		await entrypoint.handleOps([operation], account.address);
		expect(await account._remainingFeeForOperator(operator.address));
	});
});

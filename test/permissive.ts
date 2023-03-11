import { expect, should } from 'chai';
import { randomBytes } from 'ethers/lib/utils';
import { Wallet } from 'ethers/lib/index';
import hre, { ethers } from 'hardhat';
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
	let owner, operator: SignerWithAddress;
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

	it('should validate', async () => {
		await entrypoint.handleOps([operation], account.address);
	});

	it('should refuse because invalid operator', async () => {});
});

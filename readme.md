# Permissive

## Glossary

- **Account**: the ERC-4337 account
- **Operator**: the Ethereum address having permissions on the _Account_.
- **Grant**: process when the _Account_ grants permissions to an _Operator_ without permissions.
- **Revoke**: process when the _Account_ revokes all permissions to an _Operator_.

## Allowed arguments

The allowed arguments are the basic calldata arguments where each argument is replaced by a prefix and additional data:

- 0: can be any value
- 1: must be equal to the provided value
- 2: more than the provided value
- 3: less than the provided value
- 4+n: or where n is the number of options

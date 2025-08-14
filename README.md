## Proof of Humanity Group setup

## Contracts
 
### Membership condition

PoH Membership condition (`PoHMembershipCondition.sol`) - membership condition which checks if the account has PoH ID or has any linked account which hold PoH ID.

### Service contract

Service contract (`PoHGroupService.sol`) - assigned as a service in the group, used by TMS, checks if the account has valid PoH ID and it's expiry time, establishes the group trust accordingly calling trustBatchWithCondition. Ideally might be used by anyone not only TMS, as it checks the validity of the linked PoH ID onchain.

### Trust Management Service
TMS (`trust-management-service`) - trust management service, script which listens if PoHID is revoked or reclaimed (updated).

Run

```
npx tsx index.ts
```

Generate TypeScript Types

```
npx typechain --target=ethers-v6 --out-dir ./types/PoHGroupService ../contracts/out/PoHGroupService.sol/PoHGroupService.json
npx typechain --target=ethers-v6 --out-dir ./types/PoHMembershipCondition ../contracts/out/PoHMembershipCondition.sol/PoHMembershipCondition.json
npx typechain --target=ethers-v6 --out-dir ./types/IProofOfHumanity ../contracts/out/IProofOfHumanity.sol/IProofOfHumanity.json
```

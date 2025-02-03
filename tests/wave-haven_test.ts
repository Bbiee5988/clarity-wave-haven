import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create a new session",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const result = chain.callPublic("wave-haven", "create-session", [
      types.utf8("Relaxation Session"),
      types.utf8("A calming session for stress relief"),
      types.uint(100),
      types.uint(432),
      types.uint(1800)
    ], deployer.address);
    
    result.result.expectOk().expectUint(1);
  },
});

Clarinet.test({
  name: "Can purchase a session",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const buyer = accounts.get("wallet_1")!;
    const result = chain.callPublic("wave-haven", "purchase-session", [
      types.uint(1)
    ], buyer.address);
    
    result.result.expectOk().expectBool(true);
  },
});

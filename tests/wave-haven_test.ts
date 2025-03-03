import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous test cases remain unchanged]

Clarinet.test({
  name: "Can pause and unpause individual sessions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const buyer = accounts.get("wallet_1")!;
    
    // Create session
    chain.callPublic("wave-haven", "create-session", [
      types.utf8("Test Session"),
      types.utf8("Description"),
      types.uint(100),
      types.uint(432),
      types.uint(1800)
    ], deployer.address);
    
    // Pause session
    const pauseResult = chain.callPublic("wave-haven", "toggle-session-pause", [
      types.uint(1)
    ], deployer.address);
    
    pauseResult.result.expectOk().expectBool(true);
    
    // Attempt to purchase paused session
    const purchaseResult = chain.callPublic("wave-haven", "purchase-session", [
      types.uint(1)
    ], buyer.address);
    
    purchaseResult.result.expectErr().expectUint(109);
  },
});

Clarinet.test({
  name: "Can request refund within time window",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const buyer = accounts.get("wallet_1")!;
    
    // Create and purchase session
    chain.callPublic("wave-haven", "create-session", [
      types.utf8("Test Session"),
      types.utf8("Description"),
      types.uint(100),
      types.uint(432),
      types.uint(1800)
    ], deployer.address);
    
    chain.callPublic("wave-haven", "purchase-session", [
      types.uint(1)
    ], buyer.address);
    
    // Request refund
    const refundResult = chain.callPublic("wave-haven", "request-refund", [
      types.uint(1)
    ], buyer.address);
    
    refundResult.result.expectOk().expectBool(true);
  },
});

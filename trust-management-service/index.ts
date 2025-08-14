import { ethers, ZeroAddress } from 'ethers';
import dotenv from 'dotenv';

import {
  type IProofOfHumanity,
  type PoHGroupService,
  type PoHMembershipCondition,
  IProofOfHumanity__factory,
  PoHGroupService__factory,
  PoHMembershipCondition__factory
} from './types';

// Load environment variables
dotenv.config();


// Configuration
const RPC_URL = process.env.RPC_URL!;
const POH_CONTRACT_ADDRESS = process.env.POH_CONTRACT_ADDRESS || '0xa4AC94C4fa65Bb352eFa30e3408e64F72aC857bc';
const POH_SERVICE_ADDRESS = process.env.POH_SERVICE_ADDRESS || '0x33bAB4a577c9664ae5611053C4fba75AD0fAF17E';
const PRIVATE_KEY = process.env.PRIVATE_KEY!; // Optional, only if you need to send transactions

// Retry configuration
const RECONNECT_DELAY = 5000; // 5 seconds
const MAX_RETRIES = 5;
const RETRY_DELAY = 2000; // 2 seconds

class ContractEventListener {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private proofOfHumanityV2: IProofOfHumanity;
  private pohGroupService: PoHGroupService;
  private membershipCondition?: PoHMembershipCondition;
  private isListening: boolean = false;

  constructor(rpcUrl: string, pohV2ContractAddress: string, pohGroupServiceAddress: string) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl, undefined, {polling: true});
    this.wallet = new ethers.Wallet(PRIVATE_KEY, this.provider);

    this.proofOfHumanityV2 = IProofOfHumanity__factory.connect(pohV2ContractAddress, this.provider);
    this.pohGroupService = PoHGroupService__factory.connect(pohGroupServiceAddress, this.wallet);
  }

  async initialize() {
    try {
      const pohMembershipConditionAddress: string = await this.pohGroupService.pohMembershipCondition?.staticCall();
      if(pohMembershipConditionAddress)
        this.membershipCondition = PoHMembershipCondition__factory.connect(pohMembershipConditionAddress, this.wallet);

      // Get basic contract info
      console.log("Contract Info:");
      console.log(`   Address Proof Of Humanity V2 contract: ${this.proofOfHumanityV2.target}`);
      console.log(`   Address PoH group Service contract: ${this.pohGroupService.target}`);
      console.log(`   Address PoH group Membership Condition contract: ${pohMembershipConditionAddress}`);
      console.log(`   Network: ${(await this.provider.getNetwork()).name}`);
      console.log(`   Chain ID: ${(await this.provider.getNetwork()).chainId}`);
      console.log("");

      return { address: this.proofOfHumanityV2.target };
    } catch (error) {
      console.error("Failed to initialize contract:", error);
      throw error;
    }
  }

  startListening() {
    if (this.isListening) {
      console.log("Already listening for events");
      return;
    }

    console.log("Starting to listen for HumanityRevoked events...");
    this.isListening = true;

    // Listen for HumanityRevoked events
    this.proofOfHumanityV2.on(this.proofOfHumanityV2.filters.HumanityRevoked(), (eventData: any) => {
      const humanityId: string = eventData?.args?.[0];
      this.handleHumanityRevokedEvent(humanityId);
    });

    // Listen for HumanityClaimed events
    this.proofOfHumanityV2.on(this.proofOfHumanityV2.filters.HumanityClaimed(), (eventData: any) => {
      const humanityId: string = eventData?.args?.[0];
      this.handleHumanityClaimedEvent(humanityId);
    });

    console.log("Event listeners attached successfully");
  }

  stopListening() {
    if (!this.isListening) {
      console.log("Not currently listening");
      return;
    }

    this.proofOfHumanityV2.removeAllListeners();
    this.isListening = false;
    console.log("Stopped listening for events");
  }

  private async handleHumanityRevokedEvent(humanityId: string) {
    try {
      const userAccount = await this.membershipCondition?.PoHToCircles(humanityId) || ZeroAddress;
      if(userAccount.toString() != ZeroAddress) {
        const updateMembershipTx = await this.pohGroupService?.untrust(userAccount.toString());
        await updateMembershipTx.wait();
        console.log(`Account ${userAccount.toString()} removed from the group`);
      }
    } catch (error) {
      console.error("Error handling HumanityRevoked event:", error);
    }
  }

  private async handleHumanityClaimedEvent(humanityId: string) {
    try {
      const userAccount = await this.membershipCondition?.PoHToCircles(humanityId) || ZeroAddress;
      if(userAccount.toString() != ZeroAddress) {
        const updateMembershipTx = await this.pohGroupService?.register(humanityId, userAccount.toString());
        await updateMembershipTx.wait();
        console.log(`The PoHID ${humanityId} registered for account ${userAccount.toString()}`);
      }
    } catch (error) {
      console.error("Error handling HumanityClaimed event:", error);
    }
  }
}

// Main execution
async function main() {
  try {
    const listener = new ContractEventListener(RPC_URL, POH_CONTRACT_ADDRESS, POH_SERVICE_ADDRESS);
    
    // Initialize and get contract info
    await listener.initialize();
    
    // Start listening for new events
    listener.startListening();

    
    // Graceful shutdown handling
    process.on('SIGINT', () => {
      console.log("Received SIGINT, shutting down");
      listener.stopListening();
      process.exit(0);
    });
    
    process.on('SIGTERM', () => {
      console.log("Received SIGTERM, shutting down");
      listener.stopListening();
      process.exit(0);
    });
    
    // Keep the process running
    console.log("Press Ctrl+C to stop listening...");
    
  } catch (error) {
    console.error("Failed to start event listener:", error);
    process.exit(1);
  }
}

// Run the script
main().catch(console.error);

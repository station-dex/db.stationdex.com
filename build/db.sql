CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS core;

DROP DOMAIN IF EXISTS bytes32;
DROP DOMAIN IF EXISTS address;
DROP DOMAIN IF EXISTS ipfs_url;
DROP DOMAIN IF EXISTS uint8;
DROP DOMAIN IF EXISTS uint16;
DROP DOMAIN IF EXISTS uint24;
DROP DOMAIN IF EXISTS uint48;
DROP DOMAIN IF EXISTS uint112;
DROP DOMAIN IF EXISTS uint128;
DROP DOMAIN IF EXISTS uint160;
DROP DOMAIN IF EXISTS uint256;
DROP DOMAIN IF EXISTS int24;
DROP DOMAIN IF EXISTS int256;

CREATE DOMAIN bytes32 AS text;
CREATE DOMAIN address AS text;
CREATE DOMAIN ipfs_url AS text;
CREATE DOMAIN uint8 AS smallint CHECK (VALUE >= 0 AND VALUE <= 255);
CREATE DOMAIN uint16 AS integer CHECK (VALUE >= 0 AND VALUE <= 65535);
CREATE DOMAIN uint24 AS integer CHECK (VALUE >= 0 AND VALUE <= 16777215);
CREATE DOMAIN uint48 AS bigint CHECK (VALUE >= 0 AND VALUE <= 281474976710655);
CREATE DOMAIN uint112 AS numeric(180, 0) CHECK (VALUE >= 0 AND VALUE <= 5192296858534827628530496329220095);
CREATE DOMAIN uint128 AS numeric(180, 0) CHECK (VALUE >= 0 AND VALUE <= 340282366920938463463374607431768211455);
CREATE DOMAIN uint160 AS numeric(180, 0) CHECK (VALUE >= 0 AND VALUE <= 1461501637330902918203684832716283019655932542975);
CREATE DOMAIN uint256 AS numeric(180, 0) CHECK (VALUE >= 0 AND VALUE <= 115792089237316195423570985008687907853269984665640564039457584007913129639935);
CREATE DOMAIN int24 AS integer CHECK (VALUE >= -8388608 AND VALUE <= 8388607);
CREATE DOMAIN int256 AS numeric CHECK (VALUE >= -57896044618658097711785492504343953926634992332820282019728792003956564819968 AND VALUE <= 57896044618658097711785492504343953926634992332820282019728792003956564819967);

DO 
$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'readonlyuser') THEN
    CREATE ROLE readonlyuser NOLOGIN;
  END IF;
  
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'writeuser') THEN
    CREATE ROLE writeuser NOLOGIN;
    GRANT readonlyuser TO writeuser;
  END IF;
END
$$
LANGUAGE plpgsql;

CREATE TABLE core.users
(
  user_id                         uuid PRIMARY KEY DEFAULT(uuid_generate_v4()),
  referral_id                     uuid,
  account                         address NOT NULL,
  created_at                      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT(NOW()),
  banned_till                     TIMESTAMP WITH TIME ZONE
);

ALTER TABLE core.users OWNER TO writeuser;

CREATE INDEX users_referral_id_inx
ON core.users(referral_id);

CREATE UNIQUE INDEX users_account_uix
ON core.users(LOWER(account));

CREATE TABLE core.logins
(
  login_id                        uuid PRIMARY KEY DEFAULT(uuid_generate_v4()),
  user_id                         uuid NOT NULL REFERENCES core.users,
  ip_address                      national character varying(256),
  user_agent                      jsonb,
  browser                         national character varying(256),
  created_at                      TIMESTAMP WITH TIME ZONE DEFAULT(NOW())
);

ALTER TABLE core.logins OWNER TO writeuser;

CREATE TABLE core.referrals
(
  referral_id                     uuid PRIMARY KEY DEFAULT(uuid_generate_v4()),
  referrer                        uuid NOT NULL REFERENCES core.users,
  memo                            national character varying(512),
  referral_code                   national character varying(32) NOT NULL UNIQUE,
  total_referrals                 integer NOT NULL DEFAULT(0),
  deleted                         boolean NOT NULL DEFAULT(false),
  created_at                      TIMESTAMP WITH TIME ZONE DEFAULT(NOW()),
  updated_at                      TIMESTAMP WITH TIME ZONE DEFAULT(NOW()),
  deleted_at                      TIMESTAMP WITH TIME ZONE
);

ALTER TABLE core.referrals OWNER TO writeuser;

DO
$$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_referral_id_fkey') THEN
    ALTER TABLE core.users
    ADD CONSTRAINT users_referral_id_fkey
    FOREIGN KEY (referral_id) REFERENCES core.referrals;
  END IF;
END
$$
LANGUAGE plpgsql;

CREATE TABLE core.transactions
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  transaction_hash                                  text NOT NULL,
  address                                           address /* NOT NULL */,
  contract                                          address /* NOT NULL */,
  block_timestamp                                   integer NOT NULL,
  log_index                                         integer NOT NULL,
  block_number                                      text NOT NULL,
  transaction_sender                                address,
  chain_id                                          uint256 NOT NULL,
  gas_price                                         uint256,
  interface_name                                    text,
  event_name                                        text
);

CREATE INDEX transactions_transaction_hash_inx
ON core.transactions(transaction_hash);

CREATE INDEX transactions_address_inx
ON core.transactions(address);

CREATE INDEX transactions_block_timestamp_inx
ON core.transactions(block_timestamp);

CREATE INDEX IF NOT EXISTS transactions_log_index_inx
ON core.transactions(log_index);

CREATE INDEX transactions_block_number_inx
ON core.transactions(block_number);

CREATE INDEX transactions_chain_id_inx
ON core.transactions(chain_id);

CREATE INDEX transactions_event_name_inx
ON core.transactions(event_name);

/***************************************************************************************
UniswapV2Factory.json
event PairCreated(address indexed token0, address indexed token1, address pair, uint256)
***************************************************************************************/
CREATE TABLE core.v2_factory_pair_created
(
  token0                                          address NOT NULL,
  token1                                          address NOT NULL,
  pair                                            address NOT NULL,
  position                                        uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v2_factory_pair_created_token0_inx
ON core.v2_factory_pair_created(token0);

CREATE INDEX v2_factory_pair_created_token1_inx
ON core.v2_factory_pair_created(token1);

/***************************************************************************************
UniswapV2Pair.json
event Approval(address indexed owner, address indexed spender, uint256 value)
***************************************************************************************/
CREATE TABLE core.v2_pair_approval
(
  owner                                           address NOT NULL,
  spender                                         address NOT NULL,
  value                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v2_pair_approval_owner_inx
ON core.v2_pair_approval(owner);

CREATE INDEX v2_pair_approval_spender_inx
ON core.v2_pair_approval(spender);

/***************************************************************************************
UniswapV2Pair.json
event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed sentTo)
***************************************************************************************/
CREATE TABLE core.v2_pair_burn
(
  sender                                          address NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  sent_to                                         address NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v2_pair_burn_sender_inx
ON core.v2_pair_burn(sender);

CREATE INDEX v2_pair_burn_sent_to_inx
ON core.v2_pair_burn(sent_to);

/***************************************************************************************
UniswapV2Pair.json
event Mint(address indexed sender, uint256 amount0, uint256 amount1)
***************************************************************************************/

CREATE TABLE core.v2_pair_mint
(
  sender                                          address NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v2_pair_mint_sender_inx
ON core.v2_pair_mint(sender);

/***************************************************************************************
UniswapV2Pair.json
event Swap(address indexed sender, uint256 amount0In, uint256 amount1In,
          uint256 amount0Out, uint256 amount1Out, address indexed sentTo)
***************************************************************************************/

CREATE TABLE core.v2_pair_swap
(
  sender                                          address NOT NULL,
  amount0_in                                      uint256 NOT NULL,
  amount1_in                                      uint256 NOT NULL,
  amount0_out                                     uint256 NOT NULL,
  amount1_out                                     uint256 NOT NULL,
  sent_to                                         address NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v2_pair_swap_sender_inx
ON core.v2_pair_swap(sender);

CREATE INDEX v2_pair_swap_sent_to_inx
ON core.v2_pair_swap(sent_to);

/***************************************************************************************
UniswapV2Pair.json
event Sync(uint112 reserve0, uint112 reserve1)
***************************************************************************************/

CREATE TABLE core.v2_pair_sync
(
  reserve0                                        uint112 NOT NULL,
  reserve1                                        uint112 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

/***************************************************************************************
UniswapV2Pair.json
event Transfer(address indexed sender, address indexed receiver, uint256 value)
***************************************************************************************/

CREATE TABLE core.v2_pair_transfer
(
  sender                                          address NOT NULL,
  receiver                                        address NOT NULL,
  value                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v2_pair_transfer_sender_inx
ON core.v2_pair_transfer(sender);

CREATE INDEX v2_pair_transfer_receiver_inx
ON core.v2_pair_transfer(receiver);

/***************************************************************************************
UniswapV3Factory.json
event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing)
***************************************************************************************/

CREATE TABLE core.v3_factory_fee_amount_enabled
(
  fee                                             uint24 NOT NULL,
  tick_spacing                                    int24 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_factory_fee_amount_enabled_fee_inx
ON core.v3_factory_fee_amount_enabled(fee);

CREATE INDEX v3_factory_fee_amount_enabled_tick_spacing_inx
ON core.v3_factory_fee_amount_enabled(tick_spacing);

/***************************************************************************************
UniswapV3Factory.json
event OwnerChanged(address indexed oldOwner, address indexed newOwner)
***************************************************************************************/

CREATE TABLE core.owner_changed
(
  old_owner                                       address NOT NULL,
  new_owner                                       address NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX owner_changed_old_owner_inx
ON core.owner_changed(old_owner);

CREATE INDEX owner_changed_new_owner_inx
ON core.owner_changed(new_owner);

/***************************************************************************************
UniswapV3Factory.json
event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee,
                  int24 tickSpacing, address pool)
***************************************************************************************/

CREATE TABLE core.v3_factory_pool_created
(
  token0                                          address NOT NULL,
  token1                                          address NOT NULL,
  fee                                             uint24 NOT NULL,
  tick_spacing                                    int24 NOT NULL,
  pool                                            address NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_factory_pool_created_token0_inx
ON core.v3_factory_pool_created(token0);

CREATE INDEX v3_factory_pool_created_token1_inx
ON core.v3_factory_pool_created(token1);

CREATE INDEX v3_factory_pool_created_pool_inx
ON core.v3_factory_pool_created(pool);

/***************************************************************************************
NonfungibleTokenPositionDescriptor.json
event UpdateTokenRatioPriority(address token, int256 priority)
***************************************************************************************/

CREATE TABLE core.update_token_ratio_priority
(
  token                                           address NOT NULL,
  priority                                        int256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX update_token_ratio_priority_token_inx
ON core.update_token_ratio_priority(token);

/***************************************************************************************
NonfungiblePositionManager.json
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_approval
(
  owner                                           address NOT NULL,
  approved                                        address NOT NULL,
  token_id                                        uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);


CREATE INDEX nft_position_manager_approval_owner_inx
ON core.nft_position_manager_approval(owner);

CREATE INDEX nft_position_manager_approval_approved_inx
ON core.nft_position_manager_approval(approved);

CREATE INDEX nft_position_manager_approval_token_id_inx
ON core.nft_position_manager_approval(token_id);

/***************************************************************************************
NonfungiblePositionManager.json
event ApprovalForAll(address indexed owner, address indexed operator, bool approved)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_approval_for_all
(
  owner                                           address NOT NULL,
  operator                                        address NOT NULL,
  approved                                        boolean NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX nft_position_manager_approval_for_all_owner_inx
ON core.nft_position_manager_approval_for_all(owner);

CREATE INDEX nft_position_manager_approval_for_all_operator_inx
ON core.nft_position_manager_approval_for_all(operator);

CREATE INDEX nft_position_manager_approval_for_all_approved_inx
ON core.nft_position_manager_approval_for_all(approved);

/***************************************************************************************
NonfungiblePositionManager.json
event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, 
              uint256 amount1)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_collect
(
  token_id                                        uint256 NOT NULL,
  recipient                                       address NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX nft_position_manager_collect_token_id_inx
ON core.nft_position_manager_collect(token_id);

CREATE INDEX nft_position_manager_collect_recipient_inx
ON core.nft_position_manager_collect(recipient);

/***************************************************************************************
NonfungiblePositionManager.json
event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0,
                        uint256 amount1)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_decrease_liquidity
(
  token_id                                        uint256 NOT NULL,
  liquidity                                       uint128 NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX nft_position_manager_decrease_liquidity_token_id_inx
ON core.nft_position_manager_decrease_liquidity(token_id);

/***************************************************************************************
NonfungiblePositionManager.json
event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0,
                        uint256 amount1)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_increase_liquidity
(
  token_id                                        uint256 NOT NULL,
  liquidity                                       uint128 NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX nft_position_manager_increase_liquidity_token_id_inx
ON core.nft_position_manager_increase_liquidity(token_id);

/***************************************************************************************
NonfungiblePositionManager.json
event Transfer(address indexed sender, address indexed receiver, uint256 indexed tokenId)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_transfer
(
  sender                                          address NOT NULL,
  receiver                                        address NOT NULL,
  token_id                                        uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX nft_position_manager_transfer_sender_inx
ON core.nft_position_manager_transfer(sender);

CREATE INDEX nft_position_manager_transfer_receiver_inx
ON core.nft_position_manager_transfer(receiver);

CREATE INDEX nft_position_manager_transfer_token_id_inx
ON core.nft_position_manager_transfer(token_id);

/***************************************************************************************
Permit2.json
event Approval(address indexed owner, address indexed token, address indexed spender,
               uint160 amount, uint48 expiration)
***************************************************************************************/

CREATE TABLE core.permit2_approval
(
  owner                                           address NOT NULL,
  token                                           address NOT NULL,
  spender                                         address NOT NULL,
  amount                                          uint160 NOT NULL,
  expiration                                      uint48 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX permit2_approval_owner_inx
ON core.permit2_approval(owner);

CREATE INDEX permit2_approval_token_inx
ON core.permit2_approval(token);

CREATE INDEX permit2_approval_spender_inx
ON core.permit2_approval(spender);

/***************************************************************************************
Permit2.json
event Lockdown(address indexed owner, address token, address spender)
***************************************************************************************/

CREATE TABLE core.permit2_lockdown
(
  owner                                           address NOT NULL,
  token                                           address NOT NULL,
  spender                                         address NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX permit2_lockdown_owner_inx
ON core.permit2_lockdown(owner);

CREATE INDEX permit2_lockdown_token_inx
ON core.permit2_lockdown(token);

CREATE INDEX permit2_lockdown_spender_inx
ON core.permit2_lockdown(spender);

/***************************************************************************************
Permit2.json
event NonceInvalidation(address indexed owner, address indexed token,
                        address indexed spender, uint48 newNonce, uint48 oldNonce)
***************************************************************************************/

CREATE TABLE core.permit2_nonce_invalidation
(
  owner                                           address NOT NULL,
  token                                           address NOT NULL,
  spender                                         address NOT NULL,
  new_nonce                                       uint48 NOT NULL,
  old_nonce                                       uint48 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX permit2_nonce_invalidation_owner_inx
ON core.permit2_nonce_invalidation(owner);

CREATE INDEX permit2_nonce_invalidation_token_inx
ON core.permit2_nonce_invalidation(token);

CREATE INDEX permit2_nonce_invalidation_spender_inx
ON core.permit2_nonce_invalidation(spender);

/***************************************************************************************
Permit2.json
event Permit(address indexed owner, address indexed token, address indexed spender,
             uint160 amount, uint48 expiration, uint48 nonce)
***************************************************************************************/

CREATE TABLE core.permit
(
  owner                                           address NOT NULL,
  token                                           address NOT NULL,
  spender                                         address NOT NULL,
  amount                                          uint160 NOT NULL,
  expiration                                      uint48 NOT NULL,
  nonce                                           uint48 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX permit2_owner_inx
ON core.permit(owner);

CREATE INDEX permit2_token_inx
ON core.permit(token);

CREATE INDEX permit2_spender_inx
ON core.permit(spender);

/***************************************************************************************
Permit2.json
event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask)
***************************************************************************************/

CREATE TABLE core.permit2_unordered_nonce_invalidation
(
  owner                                           address NOT NULL,
  word                                            uint256 NOT NULL,
  mask                                            uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX permit2_unordered_nonce_invalidation_owner_inx
ON core.permit2_unordered_nonce_invalidation(owner);


/***************************************************************************************
UniswapV3Pool.json
event Burn(address indexed owner, int24 indexed tickLower, int24 indexed tickUpper,
           uint128 amount, uint256 amount0, uint256 amount1)
***************************************************************************************/
CREATE TABLE core.v3_pool_burn
(
  owner                                           address NOT NULL,
  tick_lower                                      int24 NOT NULL,
  tick_upper                                      int24 NOT NULL,
  amount                                          uint128 NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_burn_owner_inx
ON core.v3_pool_burn(owner);

CREATE INDEX v3_pool_burn_tick_lower_inx
ON core.v3_pool_burn(tick_lower);

CREATE INDEX v3_pool_burn_tick_upper_inx
ON core.v3_pool_burn(tick_upper);

/***************************************************************************************
UniswapV3Pool.json
event Collect(address indexed owner, address recipient, int24 indexed tickLower,
              int24 indexed tickUpper, uint128 amount0, uint128 amount1)
***************************************************************************************/

CREATE TABLE core.v3_pool_collect
(
  owner                                           address NOT NULL,
  recipient                                       address NOT NULL,
  tick_lower                                      int24 NOT NULL,
  tick_upper                                      int24 NOT NULL,
  amount0                                         uint128 NOT NULL,
  amount1                                         uint128 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_collect_owner_inx
ON core.v3_pool_collect(owner);

CREATE INDEX v3_pool_collect_recipient_inx
ON core.v3_pool_collect(recipient);

CREATE INDEX v3_pool_collect_tick_lower_inx
ON core.v3_pool_collect(tick_lower);

CREATE INDEX v3_pool_collect_tick_upper_inx
ON core.v3_pool_collect(tick_upper);

/***************************************************************************************
UniswapV3Pool.json
event CollectProtocol(address indexed sender, address indexed recipient,
                      uint128 amount0, uint128 amount1)
***************************************************************************************/

CREATE TABLE core.v3_pool_collect_protocol
(
  sender                                          address NOT NULL,
  recipient                                       address NOT NULL,
  amount0                                         uint128 NOT NULL,
  amount1                                         uint128 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_collect_protocol_sender_inx
ON core.v3_pool_collect_protocol(sender);

CREATE INDEX v3_pool_collect_protocol_recipient_inx
ON core.v3_pool_collect_protocol(recipient);

/***************************************************************************************
UniswapV3Pool.json
event Flash(address indexed sender, address indexed recipient, uint256 amount0,
            uint256 amount1, uint256 paid0, uint256 paid1)
***************************************************************************************/

CREATE TABLE core.v3_pool_flash
(
  sender                                          address NOT NULL,
  recipient                                       address NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  paid0                                           uint256 NOT NULL,
  paid1                                           uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_flash_sender_inx
ON core.v3_pool_flash(sender);

CREATE INDEX v3_pool_flash_recipient_inx
ON core.v3_pool_flash(recipient);

/***************************************************************************************
UniswapV3Pool.json
event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, 
                                         uint16 observationCardinalityNextNew)
***************************************************************************************/

CREATE TABLE core.v3_pool_increase_observation_cardinality_next
(
  observation_cardinality_next_old                uint16 NOT NULL,
  observation_cardinality_next_new                uint16 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);


/***************************************************************************************
UniswapV3Pool.json
event Initialize(uint160 sqrtPriceX96, int24 tick)
***************************************************************************************/

CREATE TABLE core.v3_pool_initialize
(
  sqrt_price_x96                                  uint160 NOT NULL,
  tick                                            int24 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

/***************************************************************************************
UniswapV3Pool.json
event Mint(address sender, address indexed owner, int24 indexed tickLower,
           int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1)
***************************************************************************************/

CREATE TABLE core.v3_pool_mint
(
  sender                                          address NOT NULL,
  owner                                           address NOT NULL,
  tick_lower                                      int24 NOT NULL,
  tick_upper                                      int24 NOT NULL,
  amount                                          uint128 NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_mint_sender_inx
ON core.v3_pool_mint(sender);

CREATE INDEX v3_pool_mint_owner_inx
ON core.v3_pool_mint(owner);

CREATE INDEX v3_pool_mint_tick_lower_inx
ON core.v3_pool_mint(tick_lower);

/***************************************************************************************
UniswapV3Pool.json
event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New,
                     uint8 feeProtocol1New)
***************************************************************************************/

CREATE TABLE core.v3_pool_set_fee_protocol
(
  fee_protocol0_old                               uint8 NOT NULL,
  fee_protocol1_old                               uint8 NOT NULL,
  fee_protocol0_new                               uint8 NOT NULL,
  fee_protocol1_new                               uint8 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

/***************************************************************************************
UniswapV3Pool.json
event Swap(address indexed sender, address indexed recipient, int256 amount0,
           int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick)
***************************************************************************************/

CREATE TABLE core.v3_pool_swap
(
  sender                                          address NOT NULL,
  recipient                                       address NOT NULL,
  amount0                                         int256 NOT NULL,
  amount1                                         int256 NOT NULL,
  sqrt_price_x96                                  uint160 NOT NULL,
  liquidity                                       uint128 NOT NULL,
  tick                                            int24 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_swap_sender_inx
ON core.v3_pool_swap(sender);

CREATE INDEX v3_pool_swap_recipient_inx
ON core.v3_pool_swap(recipient);

/***************************************************************************************
ProxyAdmin.json
event OwnershipTransferred(address indexed oldOwner, address indexed newOwner)

@note: This event is logged to the table `core.owner_changed`
***************************************************************************************/

/***************************************************************************************
UniswapV3Staker.json
event DepositTransferred(uint256 indexed tokenId, address indexed oldOwner,
                         address indexed newOwner)
***************************************************************************************/

CREATE TABLE core.deposit_transferred
(
  token_id                                        uint256 NOT NULL,
  old_owner                                       address NOT NULL,
  new_owner                                       address NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX deposit_transferred_token_id_inx
ON core.deposit_transferred(token_id);

CREATE INDEX deposit_transferred_old_owner_inx
ON core.deposit_transferred(old_owner);

CREATE INDEX deposit_transferred_new_owner_inx
ON core.deposit_transferred(new_owner);


/***************************************************************************************
UniswapV3Pool.json
event IncentiveCreated(address indexed rewardToken, address indexed pool,
                       uint256 startTime, uint256 endTime, address refundee,
                       uint256 reward)
***************************************************************************************/

CREATE TABLE core.v3_pool_incentive_created
(
  reward_token                                    address NOT NULL,
  pool                                            address NOT NULL,
  start_time                                      uint256 NOT NULL,
  end_time                                        uint256 NOT NULL,
  refundee                                        address NOT NULL,
  reward                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_incentive_created_reward_token_inx
ON core.v3_pool_incentive_created(reward_token);

CREATE INDEX v3_pool_incentive_created_pool_inx
ON core.v3_pool_incentive_created(pool);

/***************************************************************************************
UniswapV3Pool.json
event IncentiveEnded(bytes32 indexed incentiveId, uint256 refund)
***************************************************************************************/

CREATE TABLE core.v3_pool_incentive_ended
(
  incentive_id                                    bytes32 NOT NULL,
  refund                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_incentive_ended_incentive_id_inx
ON core.v3_pool_incentive_ended(incentive_id);

/***************************************************************************************
UniswapV3Pool.json
event RewardClaimed(address indexed sentTo, uint256 reward)
***************************************************************************************/

CREATE TABLE core.v3_pool_reward_claimed
(
  sent_to                                         address NOT NULL,
  reward                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_reward_claimed_sent_to_inx
ON core.v3_pool_reward_claimed(sent_to);


/***************************************************************************************
UniswapV3Pool.json
event TokenStaked(uint256 indexed tokenId, bytes32 indexed incentiveId,
                  uint128 liquidity)
***************************************************************************************/

CREATE TABLE core.v3_pool_token_staked
(
  token_id                                        uint256 NOT NULL,
  incentive_id                                    bytes32 NOT NULL,
  liquidity                                       uint128 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_token_staked_token_id_inx
ON core.v3_pool_token_staked(token_id);

CREATE INDEX v3_pool_token_staked_incentive_id_inx
ON core.v3_pool_token_staked(incentive_id);

/***************************************************************************************
UniswapV3Pool.json
event TokenUnstaked(uint256 indexed tokenId, bytes32 indexed incentiveId)
***************************************************************************************/

CREATE TABLE core.v3_pool_token_unstaked
(
  token_id                                        uint256 NOT NULL,
  incentive_id                                    bytes32 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);

CREATE INDEX v3_pool_token_unstaked_token_id_inx
ON core.v3_pool_token_unstaked(token_id);

CREATE INDEX v3_pool_token_unstaked_incentive_id_inx
ON core.v3_pool_token_unstaked(incentive_id);

/***************************************************************************************
UniversalRouter.json
event RewardsSent(uint256 amount)
***************************************************************************************/

CREATE TABLE core.universal_router_rewards_sent
(
  amount                                          uint256 NOT NULL,
  PRIMARY KEY (id)
) INHERITS (core.transactions);


CREATE TABLE core.monikers
(
  account                                       address NOT NULL PRIMARY KEY,
  name                                          text NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS monikers_account_uix
ON core.monikers(LOWER(account));

CREATE OR REPLACE FUNCTION generate_moniker(_account address)
RETURNS void
VOLATILE
AS
$$
  DECLARE _prefix text[] = '{Abiding, Able, Abounding, Aboveboard, Absolute, Absolved, Abundant, Academic, Acceptable, Accepted, Accepting, Accessible, Acclaimed, Accommodating, Accomplished, Accordant, Accountable, Accredited, Accurate, Accustomed, Acknowledged, Acquainted, Active, Actual, Acuminous, Acute, Adamant, Adaptable, Adept, Adequate, Adjusted, Admirable, Admired, Admissible, Adonic, Adorable, Adored, Adroit, Advanced, Advantaged, Advantageous, Adventuresome, Adventurous, Advisable, Aesthetic, Aesthetical, Affable, Affecting, Affectionate, Affective, Affiliated, Affined, Affluent, Affluential, Ageless, Agile, Agreeable, Aholic, Alacritous, Alert, Alive, Allegiant, Allied, Alluring, Alright, Alternate, Altruistic, Amative, Amatory, Amazing, Ambidextrous, Ambitious, Amelioratory, Amenable, Amiable, Amicable, Amusing, Anamnestic, Angelic, Aplenty, Apollonian, Appealing, Appeasing, Appetent, Appetizing, Apposite, Appreciated, Appreciative, Apprehensible, Approachable, Appropriate, Approving, Apropos, Apt, Ardent, Aristocratic, Arousing, Arresting, Articulate, Artistic, Ascendant, Ascending, Aspirant, Aspiring, Assertive, Assiduous, Assistant, Assisting, Assistive, Associate, Associated, Associative, Assured, Assuring, Astir, Astonishing, Astounding, Astronomical, Astute, Athletic, Attainable, Attendant, Attentive, Attractive, Atypical, Au fait, August, Auspicious, Authentic, Authoritative, Authorized, Autonomous, Available, Avid, Awaited, Awake, Aware, Awash, Awesome, Axiological, Balanced, Baronial, Beaming, Beatific, Beauteous, Beautified, Beautiful, Becoming, Beefy, Believable, Beloved, Benedictory, Benefic, Beneficent, Beneficial, Beneficiary, Benevolent, Benign, Benignant, Bent on, Best, Better, Big, Biggest, Bijou, Blameless, Blazing, Blessed, Blissful, Blithe, Blooming, Bodacious, Boisterous, Bold, Bona fide, Bonny, Bonzer, Boss, Bound, Bounteous, Bountiful, Brainy, Brave, Brawny, Breezy, Brief, Bright, Brill, Brilliant, Brimming, Brisk, Broadminded, Brotherly, Bubbly, Budding, Buff, Bullish, Buoyant, Businesslike, Bustling, Busy, Buxom, Calm, Calmative, Calming, Candescent, Canny, Canty, Capable, Capital, Captivating, Cared for, Carefree, Careful, Caring, Casual, Causative, Celebrated, Celeritous, Celestial, Centered, Central, Cerebral, Certain, Champion, Changeable, Changeless, Charismatic, Charitable, Charming, Cheerful, Cherished, Cherry, Chic, Childlike, Chipper, Chirpy, Chivalrous, Choice, Chosen, Chummy, Civic, Civil, Civilized, Clairvoyant, Classic, Classical, Classy, Clean, Clear, Clearheaded, Clement, Clever, Close, Clubby, Coadjutant, Coequal, Cogent, Cognizant, Coherent, Collected, Colossal, Colourful, Coltish, Comely, Comfortable, Comforting, Comic, Comical, Commanding, Commendable, Commendatory, Commending, Commiserative, Committed, Commodious, Commonsensical, Communicative, Commutual, Companionable, Compassionate, Compatible, Compelling, Competent, Complete, Completed, Complimentary, Composed, Comprehensive, Concentrated, Concise, Conclusive, Concordant, Concrete, Condolatory, Confederate, Conferrable, Confident, Congenial, Congruous, Connected, Conscientious, Conscious, Consensual, Consentaneous, Consentient, Consequential, Considerable, Considerate, Consistent, Consonant, Conspicuous, Constant, Constitutional, Constructive, Contemplative, Contemporary, Content, Contributive, Convenient, Conversant, Convictive, Convincing, Convivial, Cool, Cooperative, Coordinated, Copacetic, Copious, Cordial, Correct, Coruscant, Cosmic, Cosy, Courageous, Courteous, Courtly, Cozy, Crackerjack, Creamy, Creative, Credible, Creditable, Crisp, Crucial, Crystal (Clear), Cuddly, Cultivated, Cultured, Cunning, Curious, Current, Curvaceous, Cushy, Cute, Dainty, Dandy, Dapper, Daring, Darling, Dashing, Dauntless, Dazzling, Dear, Debonair, Decent, Deciding, Decisive, Decorous, Dedicated, Deep, Defiant, Defiantly, Definite, Deft, Delectable, Deliberate, Delicate, Delicious, Delighted, Delightful, Deluxe, Demonstrative, Demulcent, Dependable, Deserving, Designer, Desirable, Desired, Desirous, Destined, Determined, Developed, Developing, Devoted, Devotional, Devout, Dexterous, Didactic, Different, Dignified, Diligent, Dinkum, Diplomatic, Direct, Disarming, Discerning, Disciplined, Discreet, Discrete, Discriminating, Dispassionate, Distinct, Distinctive, Distinguished, Distinguishing, Diverse, Diverting, Divine, Doable, Dominant, Doting, Doubtless, Doughty, Dreamy, Driven, Driving, Durable, Dutiful, Dynamic, Dynamite, Eager, Early, Earnest, Earthly, Earthy, Easy, Easygoing, Ebullient, Eclectic, Economic, Economical, Ecstatic, Ecumenical, Edified, Educated, Educational, Effective, Effectual, Effervescent, Efficient, Effortless, Elaborate, Elated, Elating, Elder, Electric, Electrifying, Eleemosynary, Elegant, Elemental, Eligible, Eloquent, Emerging, Eminent, Empathetic, Employable, Empowered, Enamored, Enchanting, Encouraged, Encouraging, Endearing, Enduring, Energetic, Energizing, Engaging, Enhanced, Enjoyable, Enlightened, Enlightening, Enlivened, Enlivening, Enormous, Enough, Enriching, Enterprising, Entertaining, Enthralling, Enthusiastic, Enticing, Entrancing, Entrepreneurial, Epicurean, Epideictic, Equable, Equal, Equiponderant, Equipped, Equitable, Equivalent, Erotic, Erudite, Especial, Essential, Established, Esteemed, Esthetic, Esthetical, Eternal, Ethical, Euphoric, Eventful, Evident, Evocative, Exact, Exalted, Exceeding, Excellent, Exceptional, Executive, Exhilarating, Exotic, Expansive, Expectant, Expeditious, Expeditive, Expensive, Experienced, Explorative, Expressive, Exquisite, Extraordinary, Exuberant, Exultant, Fab, Fabulous, Facile, Factual, Facultative, Fain, Fair, Faithful, Famed, Familial, Familiar, Family, Famous, Fancy, Fantastic, Fascinating, Fashionable, Fast, Faultless, Favorable, Favored, Favorite, Fearless, Feasible, Fecund, Felicitous, Fertile, Fervent, Festal, Festive, Fetching, Fiery, Fine, Finer, Finest, Firm, First, Fit, Fitting, Flamboyant, Flash, Flashy, Flavorful, Flawless, Fleet, Flexible, Flourishing, Fluent, Flying, Focused, Fond, For real, Forceful, Foremost, Foresighted, Forgiving, Formidable, Forthcoming, Forthright, Fortified, Fortuitous, Fortunate, Forward, Foundational, Foxy, Fragrant, Frank, Fraternal, Free, Freely, Fresh, Friendly, Frisky, Frolicsome, Fruitful, Fulfilled, Fulfilling, Full, Fun, Funny, Futuristic, Gainful, Gallant, Galore, Game, Gamesome, Generous, Genial, Genteel, Gentle, Genuine, Germane, Gettable, Giddy, Gifted, Giving, Glad, Glamorous, Gleaming, Gleeful, Glorious, Glowing, Gnarly, Godly, Golden, Good, Goodhearted, Goodly, Gorgeous, Graced, Graceful, Gracile, Gracious, Gradely, Graithly, Grand, Grateful, Gratified, Gratifying, Great, Greatest, Greathearted, Gregarious, Groovy, Grounded, Growing, Grown, Guaranteed, Gubernatorial, Guided, Guiding, Guileless, Guiltless, Gumptious, Gustatory, Gutsy, Gymnastic, Halcyon, Hale, Hallowed, Handsome, Handy, Happening, Happy, Hardy, Harmless, Harmonious, Head, Healing, Healthful, Healthy, Heartfelt, Hearty, Heavenly, Heedful, Hegemonic, Helpful, Hep, Heralded, Heroic, Heteroclite, Heuristic, High, Highest, Highly regarded, Highly valued, Hilarious, Hip, Holy, Homely, Honest, Honeyed, Honorary, Honorable, Honored, Hopeful, Hortative, Hospitable, Hot, Hotshot, Huggy, Humane, Humanitarian, Humble, Humorous, Hunky, Hygienic, Hypersonic, Hypnotic, Ideal, Idealistic, Idiosyncratic, Idolized, Illimitable, Illuminated, Illuminating, Illustrious, Imaginative, Imitable, Immaculate, Immeasurable, Immediate, Immense, Immortal, Immune, Impartial, Impassioned, Impeccable, Impeccant, Imperturbable, Impish, Important, Impressive, Improved, Improving, Improvisational, In, Incisive, Included, Inclusive, Incomparable, Incomplex, Incontestable, Incontrovertible, Incorrupt, Incredible, Inculpable, Indefatigable, Independent, Indestructible, Indispensable, Indisputable, Individual, Individualistic, Indivisible, Indomitable, Indubitable, Industrious, Inerrant, Inexhaustible, Infallible, Infant, Infinite, Influential, Informative, Informed, Ingenious, Inimitable, Initiate, Initiative, Innocent, Innovative, Innoxious, Inquisitive, Insightful, Inspired, Inspiring, Inspiriting, Instantaneous, Instinctive, Instructive, Instrumental, Integral, Integrated, Intellectual, Intelligent, Intense, Intent, Interactive, Interconnected, Interested, Interesting, Internal, Intertwined, Intimate, Intoxicating, Intrepid, Intriguing, Introducer, Inventive, Invigorated, Invigorating, Invincible, Inviolable, Inviting, Irrefragable, Irrefutable, Irreplaceable, Irrepressible, Irreproachable, Irresistible, Jaculable, Jaunty, Jazzed, Jazzy, Jessant, Jestful, Jesting, Jewelled, Jiggish, Jigjog, Jimp, Jobbing, Jocose, Jocoserious, Jocular, Joculatory, Jocund, Joint, Jointed, Jolif, Jolly, Jovial, Joyful, Joyous, Joysome, Jubilant, Judicious, Juicy, Jump, Just, Justified, Keen, Kempt, Key, Kind, Kindly, Kindred, Kinetic, Kingly, Kissable, Knightly, Knowable, Knowing, Knowledgeable, Kooky, Kosher, Ladylike, Large, Lasting, Latitudinarian, Laudable, Laureate, Lavish, Lawful, Leading, Learned, Legal, Legendary, Legible, Legit, Legitimate, Leisured, Leisurely, Lenien, Leonine, Lepid, Lettered, Liberal, Liberated, Liberating, Lightly, Likable, Like, Liked, Likely, Limber, Lionhearted, Literary, Literate, Lithe, Lithesome, Live, Lively, Logical, Lordly, Lovable, Loved, Lovely, Loving, Loyal, Lucent, Lucid, Lucky, Lucrative, Luminous, Luscious, Lush, Lustrous, Lusty, Luxuriant, Luxurious, Made, Magical, Magnanimous, Magnetic, Magnificent, Maiden, Main, Majestic, Major, Malleable, Manageable, Managerial, Manifest, Manly, Mannerly, Many, Marked, Marvelous, Master, Masterful, Masterly, Matchless, Maternal, Mature, Maturing, Maximal, Meaningful, Mediate, Meditative, Meek, Mellow, Melodious, Memorable, Merciful, Meritable, Meritorious, Merry, Mesmerizing, Metaphysical, Meteoric, Methodical, Meticulous, Mettlesome, Mighty, Mindful, Minikin, Ministerial, Mint, Miraculous, Mirthful, Mitigative, Mitigatory, Model, Modern, Modernistic, Modest, Momentous, Moneyed, Moral, More, Most, Mother, Motivated, Motivating, Motivational, Motor, Moving, Much, Mucho, Multidimensional, Multidisciplined, Multifaceted, Munificent, Muscular, Musical, Must, Mutual, National, Nationwide, Native, Natty, Natural, Nearby, Neat, Necessary, Needed, Neighborly, Neoteric, Nestling, New, Newborn, Nice, Nifty, Nimble, Nippy, Noble, Noetic, Nonchalant, Nonpareil, Normal, Notable, Noted, Noteworthy, Noticeable, Nourished, Nourishing, Novel, Now, Nubile, Number one, Nutrimental, Objective, Obliging, Observant, Obtainable, Oecumenical, Official, OK, Okay, Olympian, On, Once, One, Onward, Open, Operative, Opportune, Optimal, Optimistic, Optimum, Opulent, Orderly, Organic, Organized, Oriented, Original, Ornamental, Outgoing, Outstanding, Overflowing, Overjoyed, Overriding, Overt, Palatable, Pally, Palpable, Par excellence, Paradisiac, Paradisiacal, Paramount, Parental, Parnassian, Participant, Participative, Particular, Partisan, Passionate, Paternal, Patient, Peaceable, Peaceful, Peachy, Peerless, Penetrating, Peppy, Perceptive, Perfect, Perky, Permanent, Permissive, Perseverant, Persevering, Persistent, Personable, Perspective, Perspicacious, Perspicuous, Persuasive, Pert, Pertinent, Pet, Petite, Phenomenal, Philanthropic, Philoprogenitive, Philosophical, Picked, Picturesque, Pierian, Pilot, Pioneering, Pious, Piquant, Pithy, Pivotal, Placid, Plausible, Playful, Pleasant, Pleased, Pleasing, Pleasurable, Plenary, Plenteous, Plentiful, Plenty, Pliable, Plucky, Plummy, Plus, Plush, Poetic, Poignant, Poised, Polished, Polite, Popular, Posh, Positive, Possible, Potent, Potential, Powerful, Practicable, Practical, Practised, Pragmatic, Praiseworthy, Prayerful, Precious, Precise, Predominant, Preeminent, Preferable, Preferred, Premier, Premium, Prepared, Preponderant, Prepotent, Present, Prestigious, Pretty, Prevailing, Prevalent, Prevenient, Primal, Primary, Prime, Prime mover, Primed, Primo, Princely, Principal, Principled, Pristine, Privileged, Prize, Prizewinning, Prized, Pro, Proactive, Probable, Probative, Procurable, Prodigious, Productive, Professional, Proficient, Profitable, Profound, Profuse, Progressive, Prolific, Prominent, Promising, Prompt, Proper, Propertied, Prophetic, Propitious, Prospective, Prosperous, Protean, Protective, Proud, Provocative, Prudent, Psyched up, Puissant, Pukka, Pulchritudinous, Pumped up, Punchy, Punctilious, Punctual, Pure, Purposeful, Quaint, Qualified, Qualitative, Quality, Quantifiable, Queenly, Quemeful, Quick, Quiet, Quietsome, Quintessential, Quirky, Quiver, Quixotic, Quotable, Racy, Rad, Radiant, Rapid, Rapturous, Rational, Reachable, Ready, Real, Realistic, Realizable, Reasonable, Reassuring, Receptive, Recherche, Recipient, Reciprocal, Recognizable, Recognized, Recommendable, Recuperative, Refined, Reflective, Refreshing, Refulgent, Regal, Regnant, Regular, Rejuvenescent, Relaxed, Relevant, Reliable, Relieved, Remarkable, Remissive, Renowned, Reputable, Resilient, Resolute, Resolved, Resounding, Resourceful, Respectable, Respectful, Resplendent, Responsible, Responsive, Restful, Restorative, Retentive, Revealing, Revered, Reverent, Revitalizing, Revolutionary, Rewardable, Rewarding, Rhapsodic, Rich, Right, Righteous, Rightful, Risible, Robust, Rollicking, Romantic, Rooted, Rosy, Round, Rounded, Rousing, Rugged, Ruling, Saccharine, Sacred, Sacrosanct, Safe, Sagacious, Sage, Saintly, Salient, Salubrious, Salutary, Salutiferous, Sanctified, Sanctimonious, Sanctioned, Sanguine, Sapid, Sapient, Sapoforic, Sassy, Satisfactory, Satisfied, Satisfying, Saucy, Saving, Savory, Savvy, Scenic, Scholarly, Scientific, Scintillating, Scrumptious, Scrupulous, Seamless, Seasonal, Seasoned, Secure, Sedulous, Seemly, Select, Selfless, Sensational, Sensible, Sensitive, Sensual, Sensuous, Sentimental, Sequacious, Serendipitous, Serene, Service, Set, Settled, Sexual, Sexy, Shapely, Sharp, Shatterproof, Sheen, Shining, Shiny, Shipshape, Showy, Shrewd, Sightly, Significant, Silken, Silky, Silver, Silvery, Simple, Sincere, Sinewy, Singular, Sisterly, Sizable, Sizzling, Skillful, Skilled, Sleek, Slick, Slinky, Smacking, Smart, Smashing, Smiley, Smooth, Snap, Snappy, Snazzy, Snod, Snug, Soaring, Sociable, Social, Societal, Soft, Soigne, Solicitous, Solid, Sonsy, Sooth, Soothing, Sophisticated, Soulful, Sound, Sovereign, Spacious, Spangly, Spanking, Sparkling, Sparkly, Special, Spectacular, Specular, Speedy, Spellbinding, Spicy, Spiffy, Spirited, Spiritual, Splendid, Splendiferous, Spontaneous, Sport, Sporting, Sportive, Sporty, Spot, Spotless, Spot on, Sprightly, Spruce, Spry, Spunky, Square, Stable, Stacked, Stainless, Stalwart, Staminal, Standard, Standing, Star, Starry, State, Stately, Statuesque, Staunch, Steadfast, Steady, Steamy, Stellar, Sterling, Sthenic, Stimulant, Stimulating, Stimulative, Stipendiary, Stirred, Stirring, Stocky, Stoical, Storied, Stout, Stouthearted, Straightforward, Strapping, Strategic, Streetwise, Strenuous, Striking, Strong, Studious, Stunning, Stupendous, Sturdy, Stylish, Suasive, Suave, Sublime, Substantial, Substant, Substantive, Subtle, Successful, Succinct, Succulent, Sufficient, Sugary, Suitable, Sultry, Summary, Summery, Sumptuous, Sunny, Super, Superabundant, Supereminent, Superethical, Superexcellent, Superb, Supercalifragilisticexpialidocious, Superfluous, Superior, Superlative, Supernal, Supersonic, Supple, Supportive, Supreme, Sure, Surpassing, Sustained, Svelte, Swank, Swashbuckling, Sweet, Swell, Swift, Swish, Sybaritic, Sylvan, Symmetrical, Sympathetic, Symphonious, Synergistic, Systematic, Tactful, Talented, Tangible, Tasteful, Tasty, Teachable, Teeming, Tempean, Temperate, Tenable, Tenacious, Tender, Terrific, Testimonial, Thankful, Thankworthy, Therapeutic, Thorough, Thoughtful, Thrilled, Thrilling, Thriving, Tidy, Tight, Timeless, Timely, Tiptop, Tireless, Titanic, Titillating, Today, Together, Tolerant, Top, Top drawer, Tops, Total, Touching, Tough, Trailblazing, Tranquil, Transcendent, Transcendental, Transient, Transnormal, Transparent, Transpicuous, Traveled, Tremendous, Tretis, Trim, Triumphant, True, Trustful, Trusting, Trustworthy, Trusty, Truthful, Tubular, Tuneful, Turgent, Tympanic, Uber, Ultimate, Ultra, Ultraprecise, Unabashed, Unadulterated, Unaffected, Unafraid, Unalloyed, Unambiguous, Unanimous, Unarguable, Unassuming, Unattached, Unbeaten, Unbelieavable, Unbiased, Unbigoted, Unblemished, Unbroken, Uncommon, Uncomplicated, Unconditional, Uncontestable, Unconventional, Uncorrupted, Uncritical, Undamaged, Undauntable, Undaunted, Undefeated, Undefiled, Undeniable, Under control, Understandable, Understanding, Understood, Undesigning, Undiminished, Undisputed, Undivided, Undoubted, Unencumbered, Unequalled, Unequivocal, Unerring, Unfailing, Unfaltering, Unfaultable, Unfeigned, Unfettered, Unflagging, Unflappable, Ungrudging, Unhampered, Unharmed, Unhesitating, Unhurt, Unified, Unimpaired, Unimpeachable, Unimpeded, Unique, United, Universal, Unlimited, Unmistakable, Unmitigated, Unobjectionable, Unobstructed, Unobtrusive, Unopposed, UnUnprejudiced, Unpretentious, Unquestionable, Unrefuted, Unreserved, Unrivalled, Unruffled, Unselfish, Unshakable, Unshaken, Unspoiled, Unspoilt, Unstoppable, Unsullied, Unsurpassed, Untarnished, Untiring, Untouched, Untroubled, Unusual, Unwavering, Up, Upbeat, Upcoming, Uplifted, Uplifting, Uppermost, Upright, Upstanding, Upward, Upwardly, Urbane, Usable, Useful, Utmost, Valiant, Valid, Validatory, Valorous, Valuable, Valued, Vast, Vaulting, Vehement, Venerable, Venturesome, Venust, Veracious, Verdurous, Veridical, Verified, Versatile, Versed, Very, Vestal, Veteran, Viable, Vibrant, Vibratile, Victor, Victorious, Vigilant, Vigorous, Virile, Virtuous, Visionary, Vital, Vivacious, Vivid, Vocal, Volant, Volitional, Voluptuous, Vulnerary, Wanted, Warm, Warranted, Wealthy, Weighty, Welcome, Welcomed, Welcoming, Weleful, Welfaring, Well, Welsome, Whimsical, Whole, Wholehearted, Wholesome, Whopping, Widely used, Willed, Willing, Winged, Winning, Winsome, Wired, Wise, With it, Within reach, Without equal, Witty, Wizard, Wizardly, Won, Wonderful, Wondrous, Workable, Worldly, Worshipful, Worth, Worthwhile, Worthy, Xenial, Xenodochial, Yern, Young, Youthful, Yummy, Zaftig, Zany, Zappy, Zazzy, Zealed, Zealful, Zealous, Zestful, Zesty, Zingy, Zippy, Zootrophic, Zooty, Affectionate, Agreeable, Amiable, Bright, Charming, Creative, Determined, Diligent, Diplomatic, Dynamic, Energetic, Friendly, Funny, Generous, Giving, Gregarious, Hardworking, Helpful, Imaginative, Kind, Likable, Loyal, Patient, Polite, Sincere, Adept, Brave, Capable, Considerate, Courageous, Faithful, Fearless, Frank, Humorous, Knowledgeable, Loving, Marvelous, Nice, Optimistic, Passionate, Persistent, Plucky, Proficient, Romantic, Sensible, Thoughtful, Warmhearted, Willing, Zestful, Amazing, Awesome, Blithesome, Excellent, Fabulous, Favorable, Fortuitous, Gorgeous, Incredible, Unique, Mirthful, Outstanding, Perfect, Philosophical, Propitious, Remarkable, Rousing, Spectacular, Splendid, Stellar, Stupendous, Super, Upbeat, Stunning, Wondrous, Alluring, Ample, Bountiful, Brilliant, Breathtaking, Dazzling, Elegant, Enchanting, Gleaming, Glimmering, Glistening, Glittering, Glowing, Lovely, Lustrous, Magnificent, Ravishing, Shimmering, Shining, Sleek, Sparkling, Twinkling, Vivid, Vibrant, Vivacious, Adaptable, Ambitious, Approachable, Competitive, Confident, Devoted, Educated, Efficient, Flexible, Focused, Honest, Independent, Inquisitive, Insightful, Organized, Personable, Productive, Qualified, Relaxed, Resourceful, Responsible}';
  DECLARE _suffix text[] = '{Ablation, Absolute Magnitude, Absolute Zero, Accretion, Accretion Disk, Achondrite, Actaea, Adrastea, Aegaeon, Aegir, Aitne, Albedo, Albedo Feature, Albiorix, Altitude, Amalthea, Ananke, Anthe, Antimatter, Antipodal Point, Aoede, Apastron, Aperture, Aphelion, Apogee, Apparent Magnitude, Arche, Ariel, Asteroid, Asteroid, Asteroid, Astrochemistry, Astronomical Unit, Atlas, Atmosphere, Atmosphere, Atom, Aurora, Aurora australis, Aurora Australis, Aurora borealis, Aurora Borealis, Autonoe, Axis, Azimuth, Bar, Bebhionm, Belinda, Bergelmir, Bestla, Bianca, Big Bang, Binary, Black hole, Black Hole, Black Moon, Blue Moon, Blueshift, Bolide, Caldera, Caliban, Callirrhoe, Callisto, Calypso, Carme, Carpo, Catena, Cavus, Celestial Equator, Celestial Poles, Celestial Sphere, Cepheid Variable, Chaldene, Chaos, Charon, Chasma, Chondrite, Chondrule, Chromosphere, Circumpolar Star, Circumstellar Disk, Coma, Comet, Comet, Conjunction, Constellation, Constellation, Cordelia, Corona, Corona, Cosmic Ray, Cosmic String, Cosmogony, Cosmology, Cosmos, Crater, Crater, Cressida, Cupid, Cyllene, Daphnis, Dark Matter, Debris Disk, Declination, Deimos, Density, Desdemona, Despina, Dia, Dione, Disk, Doppler Effect, Double Asteroid, Double Star, Dwarf planet, Dwarf Planet, Dysnomia, Eccentricity, Eclipse, Eclipsing Binary, Ecliptic, Eirene, Ejecta, El Niño, Elara, Electromagnetic Radiation, Electromagnetic Spectrum, Electromagnetic Spectrum, Ellipse, Elliptical Galaxy, Elongation, Enceladus, Ephemeris, Epimetheus, Equator, Equinox, Erinome, Eris, Erriapus, Ersa, Escape Velocity, Euanthe, Eukelade, Eupheme, Euporie, Europa, Eurydome, Event Horizon, Evolved Star, Exoplanet, Extinction, Extragalactic, Extraterrestrial, Eyepiece, Faculae, Farbauti, Fenrir, Ferdinand, Filament, Finder, Fireball, Flare Star, Fornjot, Francisco, Galactic Halo, Galactic Nucleus, Galatea, Galaxy, Galaxy, Galilean Moons, Gamma rays, Gamma-ray, Ganymede, Gas, Geosynchronous Orbit, Giant Molecular Cloud, Globular Cluster, Gonggong, GPS, Granulation, Gravitational Lens, Gravity, Gravity, Greenhouse Effect, Greenhouse gas, Greip, Halimede, Harpalyke, Hati, Haumea , Hegomone, Helene, Helike, Heliopause, Heliosphere, Hermippe, Herse, Hi\iaka, Himalia, Hippocamp, Hydra, Hydrogen, Hydrostatic equilibrium, Hypergalaxy, Hyperion, Hyrrokkin, Iapetus, Ice, Ijiraq, Illmare, Inclination, Inferior Conjunction, Inferior Planet, Infrared, Interplanetary Magnetic Field, Interstellar Medium, Io, Ionosphere, Iron Meteorite, Irregular Galaxy, Irregular Satellite, Isonoe, Jansky, Janus, Jarnsaxa, Jet, Juliet, Kale, Kallichore, Kalyke, Kari, Kelvin, Kerberos, Kiloparsec, Kirkwood Gaps, Kiviuq, Kore, Kuiper Belt, Kuiper Belt, La Niña, Lagrange Point, Laomedeia, Larissa, Leda, Lenticular Galaxy, Libration, Light year, Light Year, Limb, Local Group, Locaste, Loge, Luminosity, Luna, Lunar Eclipse, Lunar Month, Lunation, Lysithea, Mab, Magellanic Clouds, Magnetic field, Magnetic Field, Magnetic Pole, Magnetosphere, Magnitude, Main Belt, Major Planet, Makemake, Mare, Margeret, Mass, Mass, Matter, Matter, Megaclite, Meridian, Metal, Meteor, Meteor, Meteor Shower, Meteorite, Meteorite, Meteoroid, Meteoroid, Methone, Metis, Microwaves, Millibar, Mimas, Minor Planet, Miranda, Mneme, Molecular Cloud, Molecule, Moon, Mundilfari, Nadir, Naiad, Namaka, Narvi, Nebula, Nebula, Nereid, Neso, Neutrino, Neutron star, Neutron Star, Nix, Nova, Nuclear Fusion, Oberon, Oblateness, Obliquity, Occultation, Oort Cloud, Oort Cloud, Open Cluster, Ophelia, Opposition, Orbit, Orbit, Orcus, Orthosie, Ozone layer, Paaliaq, Pallene, Pan, Pandia, Pandora, Parallax, Parsec, Particle, Pasiphae, Pasithee, Patera, Penumbra, Perdita, Perigee, Perihelion, Perturb, Phase, Philphrosyne, Phobos, Phoebe, Photon, Photosphere, Planemo, Planet, Planet, Planetary Nebula, Planetesimal, Planitia, Planum, Plasma, Polydueces, Portia, Praxidike, Precession, Prograde Orbit, Prometheus, Prominence, Proper Motion, Prospero, Proteus, Protoplanetary Disk, Protostar, Psamathe, Puck, Pulsar, Pulsar, Quadrature, Quaoar, Quasar, Quasar, Quasi - Stellar Object, Radial Velocity, Radiant, Radiation, Radiation, Radiation Belt, Radio Galaxy, Radio waves, Radioactive, Red Giant, Redshift, Regular Satellite, Resonance, Retrograde Motion, Retrograde Orbit, Rhea, Right Ascension, Ring Galaxy, Roche Limit, Rosalind, Rotation, Saber\s Beads, Salacia, Sao, Saros Series, Satellite, Satellite, Scarp, Setebos, Seyfert Galaxy, Shell Star, Shepherd Satellite, Siarnaq, Sidereal, Sidereal Month, Sidereal Period, Singularity, Sinope, Skathi, Skoll, Small Solar System Body, Solar Cycle, Solar Eclipse, Solar flare, Solar Flare, Solar Nebula, Solar Panel, Solar system, Solar wind, Solar Wind, Solstice, Space weather, Spacecraft, Spectrometer, Spectroscopy, Spectrum, Speed of Light, Spicules, Spiral Galaxy, Sponde, Star, Star, Star Cluster, Steady State Theory, Stellar Wind, Stephano, Stone Meteorite, Stony Iron, Styx, Sun, Sunspot, Supergiant, Superior Conjunction, Superior Planet, Supermassive, Supermoon, Supernova, Supernova, Supernova Remnant, Surtur, Suttungr, Sycorax, Synchronous Rotation, Synodic Month, Synodic Period, Tarqeq, Tarvos, Taygete, Tectonics, Tektite, Telescope, Telesto, Terminator, Terrestrial, Terrestrial Planet, Tethys, Thalassa, Thebe, Thelxinoe, Themisto, Thrymr, Thyone, Tidal Force, Tidal Heating, Titan, Titania, Trans-Neptunian Object, Transit, Trinculo, Triton (13.4), Trojan, Ultraviolet, Ultraviolet, Umbra, Umbriel, Universal Time, Universe, Vacuum, Van Allen Belts, Vanth, Varda, Variable Star, Virgo Cluster, Visible light, Visible Light, Visual Magnitude, Volcano, Wave, Wavelength, Weywot, White Dwarf, X-Rays, Xiangliu, Yellow Dwarf, Ymir, Zenith, Zodiac, Zodiacal Light}';
  DECLARE _moniker text = CONCAT((array_sample(_prefix, 1))[1], ' ', (array_sample(_suffix, 1))[1]);
BEGIN
  IF(_account IS NULL) THEN
    RETURN;
  END IF;

  INSERT INTO core.monikers(account, name)
  SELECT LOWER(_account), _moniker
  ON CONFLICT DO NOTHING;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION generate_moniker OWNER TO writeuser;

/*****************************************************************
-----------------------MONIKER TRIGGERS-----------------------
*****************************************************************/

CREATE OR REPLACE FUNCTION core.users_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.account);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.users;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.users
FOR EACH ROW EXECUTE FUNCTION core.users_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.transactions_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.address);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.transactions;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.transactions_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v2_pair_approval_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.spender);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v2_pair_approval;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v2_pair_approval
FOR EACH ROW EXECUTE FUNCTION core.v2_pair_approval_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v2_pair_burn_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.sent_to);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v2_pair_burn;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v2_pair_burn
FOR EACH ROW EXECUTE FUNCTION core.v2_pair_burn_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v2_pair_mint_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v2_pair_mint;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v2_pair_mint
FOR EACH ROW EXECUTE FUNCTION core.v2_pair_mint_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v2_pair_swap_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.sent_to);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v2_pair_swap;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v2_pair_swap
FOR EACH ROW EXECUTE FUNCTION core.v2_pair_swap_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v2_pair_transfer_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.receiver);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v2_pair_transfer;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v2_pair_transfer
FOR EACH ROW EXECUTE FUNCTION core.v2_pair_transfer_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.owner_changed_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.old_owner);
  PERFORM generate_moniker(NEW.new_owner);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.owner_changed;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.owner_changed
FOR EACH ROW EXECUTE FUNCTION core.owner_changed_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.nft_position_manager_approval_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.approved);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.nft_position_manager_approval;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.nft_position_manager_approval
FOR EACH ROW EXECUTE FUNCTION core.nft_position_manager_approval_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.nft_position_manager_approval_for_all_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.operator);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.nft_position_manager_approval_for_all;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.nft_position_manager_approval_for_all
FOR EACH ROW EXECUTE FUNCTION core.nft_position_manager_approval_for_all_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.nft_position_manager_collect_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.recipient);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.nft_position_manager_collect;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.nft_position_manager_collect
FOR EACH ROW EXECUTE FUNCTION core.nft_position_manager_collect_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.nft_position_manager_transfer_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.receiver);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.nft_position_manager_transfer;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.nft_position_manager_transfer
FOR EACH ROW EXECUTE FUNCTION core.nft_position_manager_transfer_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.permit2_approval_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.spender);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.permit2_approval;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.permit2_approval
FOR EACH ROW EXECUTE FUNCTION core.permit2_approval_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.permit2_lockdown_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.spender);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.permit2_lockdown;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.permit2_lockdown
FOR EACH ROW EXECUTE FUNCTION core.permit2_lockdown_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.permit2_nonce_invalidation_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.spender);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.permit2_nonce_invalidation;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.permit2_nonce_invalidation
FOR EACH ROW EXECUTE FUNCTION core.permit2_nonce_invalidation_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.permit_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.spender);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.permit;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.permit
FOR EACH ROW EXECUTE FUNCTION core.permit_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.permit2_unordered_nonce_invalidation_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.permit2_unordered_nonce_invalidation;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.permit2_unordered_nonce_invalidation
FOR EACH ROW EXECUTE FUNCTION core.permit2_unordered_nonce_invalidation_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_burn_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_burn;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_burn
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_burn_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_collect_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.owner);
  PERFORM generate_moniker(NEW.recipient);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_collect;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_collect
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_collect_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_collect_protocol_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.recipient);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_collect_protocol;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_collect_protocol
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_collect_protocol_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_flash_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.recipient);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_flash;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_flash
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_flash_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_mint_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.owner);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_mint;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_mint
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_mint_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_swap_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sender);
  PERFORM generate_moniker(NEW.recipient);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_swap;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_swap
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_swap_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.deposit_transferred_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.old_owner);
  PERFORM generate_moniker(NEW.new_owner);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.deposit_transferred;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.deposit_transferred
FOR EACH ROW EXECUTE FUNCTION core.deposit_transferred_moniker_trigger();
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION core.v3_pool_reward_claimed_moniker_trigger()
RETURNS trigger
AS
$$
BEGIN
  PERFORM generate_moniker(NEW.sent_to);
  RETURN NEW;
END
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS moniker_trigger ON core.v3_pool_reward_claimed;

CREATE TRIGGER moniker_trigger
BEFORE INSERT ON core.v3_pool_reward_claimed
FOR EACH ROW EXECUTE FUNCTION core.v3_pool_reward_claimed_moniker_trigger();
--------------------------------------------------------------------------------


CREATE TABLE IF NOT EXISTS environment_variables
(
  key                                            text NOT NULL PRIMARY KEY,
  value                                          text NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS environment_variables_key_uix
ON environment_variables(LOWER(key));

ALTER TABLE environment_variables OWNER TO writeuser;

CREATE OR REPLACE FUNCTION env(_key text, _value text)
RETURNS void
AS
$$
BEGIN
  IF(_value IS NULL) THEN
    DELETE FROM environment_variables
    WHERE LOWER(key) = LOWER(_key);
    RETURN;
  END IF;

  INSERT INTO environment_variables(key, value)
  VALUES (_key, _value)
  ON CONFLICT (key)
  DO UPDATE SET value = _value;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION env(_key text, _value text) OWNER TO writeuser;

CREATE OR REPLACE FUNCTION env(_key text)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN value FROM environment_variables
  WHERE LOWER(key) = LOWER(_key);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION env(_key text) OWNER TO writeuser;

DELETE FROM environment_variables;

-- common

SELECT env('swap:point',                                                '15');
SELECT env('liquidity:point',                                           '1');
SELECT env('referral:points',                                           '0.1');

-- X Layer Mainnet: 196

SELECT env('196:USDT',                                                  '0x1e4a5963abfd975d8c9021ce480b42188849d41d');
SELECT env('196:WOKB',                                                  '0xe538905cf8410324e03a5a23c1c177a474d59b2b');
SELECT env('196:WETH',                                                  '0x5a77f1443d16ee5761d310e38b62f77f726bc71c');
SELECT env('196:v2:WOKB/USDT',                                          '0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798');
SELECT env('196:v3:WOKB/USDT',                                          '0x11e7c6ff7ad159e179023bb771aec61db6d9234d');
SELECT env('196:v3:WETH/USDT',                                          '0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a');

SELECT env('196:0x1e4a5963abfd975d8c9021ce480b42188849d41d:name',       'USDT');
SELECT env('196:0xe538905cf8410324e03a5a23c1c177a474d59b2b:name',       'WOKB');
SELECT env('196:0x5a77f1443d16ee5761d310e38b62f77f726bc71c:name',       'WETH');
SELECT env('196:0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798:name',       'v2:WOKB/USDT');
SELECT env('196:0x11e7c6ff7ad159e179023bb771aec61db6d9234d:name',       'v3:WOKB/USDT');
SELECT env('196:0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a:name',       'v3:WETH/USDT');

SELECT env('196:0x1e4a5963abfd975d8c9021ce480b42188849d41d:decimals',   '6');
SELECT env('196:0xe538905cf8410324e03a5a23c1c177a474d59b2b:decimals',   '18');
SELECT env('196:0x5a77f1443d16ee5761d310e38b62f77f726bc71c:decimals',   '18');

SELECT env('196:contracts', '{0xa91f3e6935859d3333c4e528e74f3284124dcf51,0x90Abedb3F1d1ea4f945153440Db7AC8B74e81BAc ,0xf89f39e39cf07f6862c084c2e1dbc913b521263a ,0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798 ,0x11e7c6ff7ad159e179023bb771aec61db6d9234d ,0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a}');

-- X Layer Testnet: 195

SELECT env('195:WOKB',                                                  '0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6');
SELECT env('195:USDT',                                                  '0xeb45D32425a02a5A9d8500375932f1cCe5781b96');
SELECT env('195:USDC',                                                  '0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248');
SELECT env('195:v3:WOKB/USDC',                                          '0x725b0caa0a38564b90e9ce608e037e2556de4f87');
SELECT env('195:v2:USDC/USDT',                                          '0x388c8ca45bccf0c430ef6955a526b1dc1bab765a');
SELECT env('195:v3:USDC/USDT',                                          '0x26f007e7c978856a70f8d2e8a79300496e96a1ba');

SELECT env('195:0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6:name',       'WOKB');
SELECT env('195:0xeb45D32425a02a5A9d8500375932f1cCe5781b96:name',       'USDT');
SELECT env('195:0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248:name',       'USDC');
SELECT env('195:0x725b0caa0a38564b90e9ce608e037e2556de4f87:name',       'v3:WOKB/USDC');
SELECT env('195:0x388c8ca45bccf0c430ef6955a526b1dc1bab765a:name',       'v2:USDC/USDT');
SELECT env('195:0x26f007e7c978856a70f8d2e8a79300496e96a1ba:name',       'v3:USDC/USDT');

SELECT env('195:0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6:decimals',   '18');
SELECT env('195:0xeb45D32425a02a5A9d8500375932f1cCe5781b96:decimals',   '18');
SELECT env('195:0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248:decimals',   '6');

SELECT env('195:contracts', '{0x5182e0fcb8619f41c0f40da342b4dc82c088f5e5, 0xa639d6f6437a487201f414d787fdcacfa627b007, 0x0623806922db8bfe8a5d0996c73ea2fb5999ee82, 0x6e19cb93b94433f59a3257b6e995b95e655e09a2}');


CREATE OR REPLACE VIEW whitelisted_pool_view
AS
WITH whitelisted_pools
AS
(
  SELECT
    196                                                             AS chain_id,
    'v2'                                                            AS version,
    '196:WOKB/USDT'                                                 AS name,
    env('196:v2:WOKB/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WOKB')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    196                                                             AS chain_id,
    'v3'                                                            AS version,
    '196:WOKB/USDT'                                                 AS name,
    env('196:v3:WOKB/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WOKB')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    196                                                             AS chain_id,
    'v3'                                                            AS version,
    '196:WETH/USDT'                                                 AS name,
    env('196:v3:WETH/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WETH')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v2'                                                            AS version,
    '195:WOKB/USDC'                                                 AS name,
    env('195:v3:WOKB/USDC')                                         AS pool_address,
    env('195:WOKB')                                                 AS token0,
    env('195:USDC')                                                 AS token1,
    false                                                           AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v3'                                                            AS version,
    '195:USDC/USDT'                                                 AS name,
    env('195:v2:USDC/USDT')                                         AS pool_address,
    env('195:USDC')                                                 AS token0,
    env('195:USDT')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v3'                                                            AS version,
    '195:USDC/USDT'                                                 AS name,
    env('195:v3:USDC/USDT')                                         AS pool_address,
    env('195:USDC')                                                 AS token0,
    env('195:USDT')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
)
SELECT * FROM whitelisted_pools;

ALTER VIEW whitelisted_pool_view OWNER TO writeuser;

CREATE OR REPLACE FUNCTION create_referral
(
  _login_id                       uuid,
  _memo                           national character varying(512)
)
RETURNS text
AS
$$
  ----------------------------------------------------------------
  DECLARE _active_limit           integer = 12;
  DECLARE _total_limit            integer = 24;
  ----------------------------------------------------------------
  DECLARE _referral_id            uuid = uuid_generate_v4();
  DECLARE _referrer_id            uuid = get_user_id_by_login_id(_login_id);
  DECLARE _referral_code          text;
  DECLARE _active_count           integer;
  DECLARE _total_count            integer;
BEGIN
  SELECT COUNT(*) INTO _active_count
  FROM core.referrals
  WHERE 1 = 1
  AND NOT deleted
  AND referrer = _referrer_id;

  SELECT COUNT(*) INTO _total_count
  FROM core.referrals
  WHERE 1 = 1
  AND referrer = _referrer_id;

  IF(_active_count >= _active_limit OR _total_count >= _total_limit) THEN
    RETURN NULL;
  END IF;

  _referral_code := get_referral_code();

  INSERT INTO core.referrals(referral_id, referrer, memo, referral_code)
  SELECT _referral_id, _referrer_id, _memo, _referral_code;

  RETURN _referral_code;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION create_referral OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_account_by_user_id(_user_id uuid)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.users.account
  FROM core.users
  WHERE 1 = 1
  AND core.users.user_id = _user_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_account_by_user_id(_user_id uuid) OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_account(_account text)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.monikers.name
  FROM core.monikers
  WHERE core.monikers.account = _account;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_account OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_login_id(_login_id uuid)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN get_name_by_user_id(get_user_id_by_login_id(_login_id));
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_login_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_user_id(_user_id uuid)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.monikers.name
  FROM core.users
  INNER JOIN core.monikers
  ON core.monikers.account = core.users.account
  WHERE 1 = 1
  AND core.users.user_id = _user_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_user_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_point_detail
(
  _page_number                                    integer,
  _account                                        address
)
RETURNS TABLE
(
  version                                         text,
  chain_id                                        uint256,
  action                                          text,
  account                                         address,
  pool_name                                       text,
  block_timestamp                                 integer,
  transaction_hash                                text,
  amount                                          numeric,
  points                                          numeric,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer,
  total_points                                    numeric,
  rank                                            integer,
  moniker                                         text
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _pagination_query                       text;
  DECLARE _page_size                              integer = 25;
  DECLARE _offset                                 integer;
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
  DECLARE _total_points                           numeric;
  DECLARE _rank                                   bigint;
  DECLARE _moniker                                text;
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  SELECT point_view.points, point_view.rank, point_view.moniker
  INTO _total_points, _rank, _moniker
  FROM point_view
  WHERE point_view.account = _account;

  IF(_total_points IS NULL) THEN
    RETURN;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM point_detail_view
      WHERE 1 = 1
      AND account = %s
    )', quote_literal(_account));

  _pagination_query := CONCAT(_query, E'\n\tSELECT COUNT(*) FROM result;');

  EXECUTE _pagination_query INTO _total_records;

  _total_pages := COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  _offset := (_page_number - 1) * _page_size;

  _query := CONCAT
    (
      _query,
      E'\n', 
      format
      (
        E'\tSELECT
          *,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages,
          %s AS total_points,
          %s AS rank,
          %L AS moniker
        FROM result
        ORDER BY block_timestamp DESC
        LIMIT %s
        OFFSET %s;',
        _page_size,
        _page_number,
        _total_records,
        _total_pages,
        _total_points,
        _rank,
        _moniker,
        _page_size, --limit
        _offset
      )
    );

  RAISE NOTICE '%', _query;

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_point_detail OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_points
(
  _page_number                                    integer,
  _search_account                                 text
)
RETURNS TABLE
(
  rank                                            bigint,
  moniker                                         text,
  account                                         address,
  points                                          numeric,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer  
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _pagination_query                       text;
  DECLARE _page_size                              integer = 25;
  DECLARE _offset                                 integer;
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM point_view
      WHERE 1 = 1
      AND account ILIKE %s
    )', quote_literal_ilike(_search_account));

  _pagination_query := CONCAT(_query, E'\n\tSELECT COUNT(*) FROM result;');

  EXECUTE _pagination_query INTO _total_records;

  _total_pages := COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  _offset := (_page_number - 1) * _page_size;

  _query := CONCAT
    (
      _query,
      E'\n', 
      format
      (
        E'\tSELECT
          *,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages
        FROM result
        ORDER BY rank ASC
        LIMIT %1$s
        OFFSET %5$s;', 
        _page_size,
        _page_number,
        _total_records,
        _total_pages,
        _offset
      )
    );

  RAISE NOTICE '%', _query;

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_points OWNER TO writeuser;

DROP FUNCTION IF EXISTS get_point_detail
(
  _page_number                                    integer,
  _account                                        address
);

CREATE OR REPLACE FUNCTION get_point_detail
(
  _page_number                                    integer,
  _account                                        address
)
RETURNS TABLE
(
  version                                         text,
  chain_id                                        uint256,
  action                                          text,
  account                                         address,
  pool_name                                       text,
  block_timestamp                                 integer,
  transaction_hash                                text,
  amount                                          numeric,
  points                                          numeric,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer  
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _pagination_query                       text;
  DECLARE _page_size                              integer = 25;
  DECLARE _offset                                 integer;
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM point_detail_view
      WHERE 1 = 1
      AND account = %s
    )', quote_literal(_account));

  _pagination_query := CONCAT(_query, E'\n\tSELECT COUNT(*) FROM result;');

  EXECUTE _pagination_query INTO _total_records;

  _total_pages := COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  _offset := (_page_number - 1) * _page_size;

  _query := CONCAT
    (
      _query,
      E'\n', 
      format
      (
        E'\tSELECT
          *,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages
        FROM result
        ORDER BY block_timestamp DESC
        LIMIT %1$s
        OFFSET %5$s;', 
        _page_size,
        _page_number,
        _total_records,
        _total_pages,
        _offset
      )
    );

  RAISE NOTICE '%', _query;

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_point_detail OWNER TO writeuser;

-- SELECT * FROM get_points(1, '%%');


CREATE OR REPLACE FUNCTION get_referral_code()
RETURNS text
STABLE
AS
$$
  DECLARE _prefixes text[] = '{Zum,Pix,Fei,Ras,Fozz,Quix,Zeb,Mop,Glip,Vun,Dax,Jiv,Kex,Bop,Yuz,Nix,Pev,Lox,Ruv,Zep,Quaz,Drix,Yop,Wix,Ziv,Kip,Gox,Vex,Jaz,Qux,Blip,Fex,Piz,Jux,Voz,Zix,Gep,Quip,Pox,Ziv,Fip,Xux,Koz,Vep,Lix,Zox,Mux,Quex,Ziz,Diz,Zup,Vix,Pox,Tix,Zun,Qip,Vux,Zem,Bux,Nux,Zat,Vop,Zob,Xix,Zav,Qev,Zut,Zop,Vez,Zil,Quem,Zim,Zul,Vub,Zik,Zed,Vez,Zor,Xax,Zun,Zay,Quem,Zad,Zol,Vex,Ziv,Zob,Quam,Zol,Zix,Zop,Vez,Zup,Zep,Zog,Zev,Zin,Zab,Zof,Zem,Zuz,Zav,Zul,Zor}';
  DECLARE _suffix text = array_to_string(ARRAY(SELECT chr((48 + round(random() * 9)) :: integer) FROM generate_series(1,7)), '');
  DECLARE _code text;
BEGIN
  _code := CONCAT
  (
    UPPER(_prefixes[1 + floor((random() * array_length(_prefixes, 1)))::int]),
    '-',
    _suffix
  );

  IF EXISTS(SELECT 1 FROM core.referrals WHERE referral_code = _code) THEN
    RETURN get_referral_code();
  END IF;

  RETURN _code;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_referral_code OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_referrer(_account text)
RETURNS uuid
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.referrals.referrer
  FROM core.referrals
  INNER JOIN core.users
  ON core.users.referral_id = core.referrals.referral_id
  AND core.users.account = _account;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_referrer(_account text) OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_user_id_by_login_id(_login_id uuid)
RETURNS uuid
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN user_id
  FROM core.logins
  WHERE 1 = 1
  AND core.logins.login_id = _login_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_user_id_by_login_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION quote_literal_ilike(_ilike text)
RETURNS text
IMMUTABLE
AS
$$
BEGIN
  RETURN quote_literal(CONCAT('%', TRIM(_ilike), '%'));
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION quote_literal_ilike OWNER TO writeuser;

CREATE OR REPLACE FUNCTION sign_in
(
  _account                        text,
  _referral_code                  text,
  _ip_address                     text,
  _user_agent                     jsonb,
  _browser                        text
)
RETURNS jsonb
AS
$$
  ----------------------------------------------------------------
  DECLARE _window                 interval = '10 minutes';
  DECLARE _ban_duration           interval = '6 hours';
  DECLARE _login_limit            integer = 5;
  ----------------------------------------------------------------
  DECLARE _referral_id            uuid;
  DECLARE _user_id                uuid;
  DECLARE _login_id               uuid = uuid_generate_v4();
  DECLARE _login_count            integer;
  DECLARE _new_user               boolean = false;
  DECLARE _moniker                text;
BEGIN
  SELECT referral_id INTO _referral_id
  FROM core.referrals
  WHERE NOT deleted
  AND LOWER(referral_code) = LOWER(_referral_code);

  IF (_referral_id IS NULL AND COALESCE(_referral_code, '') <> '') THEN
    RAISE EXCEPTION USING ERRCODE = 'X1892', MESSAGE = 'Invalid referral code';
    RETURN NULL;
  END IF;

  /**
   * ----------------------------------------------------------------
   * If the user is logging in for the first time, add the user.
   * ----------------------------------------------------------------
   */
  IF NOT EXISTS
  (
    SELECT 1 FROM core.users
    WHERE LOWER(account) = LOWER(_account)
  ) THEN
    _new_user := true;

    INSERT INTO core.users(account, referral_id)
    SELECT LOWER(_account), _referral_id;

    /**
     * ----------------------------------------------------------------
     * For valid referrals, increment the referral count.
     * ----------------------------------------------------------------
     */
    IF(_referral_id IS NOT NULL) THEN
      UPDATE core.referrals
      SET total_referrals = total_referrals + 1
      WHERE referral_id = _referral_id;
    END IF;
  END IF;


  IF(NOT _new_user AND COALESCE(_referral_code, '') <> '') THEN
    RAISE EXCEPTION USING ERRCODE = 'X1892', MESSAGE = 'Invalid referral code';
    RETURN NULL;
  END IF;

  SELECT user_id INTO _user_id
  FROM core.users
  WHERE LOWER(account) = LOWER(_account);

  /**
   * ----------------------------------------------------------------
   * Reject the login if the user is banned.
   * ----------------------------------------------------------------
   */
  IF EXISTS
  (
    SELECT 1 FROM core.users
    WHERE user_id = _user_id 
    AND banned_till > NOW()
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'X1891', MESSAGE = 'Soft ban for spamming';
    RETURN NULL;
  END IF;

  /**
   * ----------------------------------------------------------------
   * Prevent spam logins when a user makes more than 
   * 5 login attempts within a 10-minute window.
   * ----------------------------------------------------------------
   */
  SELECT COUNT(*) INTO _login_count
  FROM core.logins
  WHERE user_id = _user_id
  AND created_at > NOW() - _window;

  IF(_login_count >= _login_limit) THEN
    UPDATE core.users
    SET banned_till = NOW() + _ban_duration
    WHERE user_id = _user_id;

    RAISE EXCEPTION USING ERRCODE = 'X1893', MESSAGE = 'Login limit exceeded';
    RETURN NULL;
  END IF;

  INSERT INTO core.logins(login_id, user_id, ip_address, user_agent, browser)
  SELECT _login_id, _user_id, _ip_address, _user_agent, _browser;

  PERFORM generate_moniker(_account);

  _moniker := get_name_by_user_id(_user_id);

  RETURN jsonb_build_object
  (
    'loginId', _login_id,
    'moniker', _moniker
  );
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION sign_in OWNER TO writeuser;

CREATE OR REPLACE VIEW liquidity_transaction_view
AS
SELECT
  'v2'                                                          AS version,
  'remove'                                                      AS action,
  core.v2_pair_burn.chain_id                                    AS chain_id,
  core.v2_pair_burn.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v2_pair_burn.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v2_pair_burn.block_timestamp,
  core.v2_pair_burn.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_burn.amount0)
    ELSE ABS(core.v2_pair_burn.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_burn.amount1)
    ELSE ABS(core.v2_pair_burn.amount0)
  END                                                           AS token_amount
FROM core.v2_pair_burn
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v2_pair_burn.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v2_pair_burn.contract) = ANY(LOWER(env(CONCAT(core.v2_pair_burn.chain_id, ':contracts')))::text[])
AND LOWER(core.v2_pair_burn.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v2'

UNION ALL

SELECT
  'v2'                                                          AS version,
  'add'                                                         AS action,
  core.v2_pair_mint.chain_id                                    AS chain_id,
  core.v2_pair_mint.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v2_pair_mint.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v2_pair_mint.block_timestamp,
  core.v2_pair_mint.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_mint.amount0)
    ELSE ABS(core.v2_pair_mint.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_mint.amount1)
    ELSE ABS(core.v2_pair_mint.amount0)
  END                                                           AS token_amount
FROM core.v2_pair_mint
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v2_pair_mint.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v2_pair_mint.contract) = ANY(LOWER(env(CONCAT(core.v2_pair_mint.chain_id, ':contracts')))::text[])
AND LOWER(core.v2_pair_mint.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v2'

UNION ALL

SELECT
  'v3'                                                          AS version,
  'add'                                                         AS action,
  core.v3_pool_mint.chain_id                                    AS chain_id,
  core.v3_pool_mint.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v3_pool_mint.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v3_pool_mint.block_timestamp,
  core.v3_pool_mint.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_mint.amount0)
    ELSE ABS(core.v3_pool_mint.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_mint.amount1)
    ELSE ABS(core.v3_pool_mint.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_mint
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v3_pool_mint.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v3_pool_mint.contract) = ANY(LOWER(env(CONCAT(core.v3_pool_mint.chain_id, ':contracts')))::text[])
AND LOWER(core.v3_pool_mint.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v3'

UNION ALL

SELECT
  'v3'                                                          AS version,
  'remove'                                                      AS action,
  core.v3_pool_burn.chain_id                                    AS chain_id,
  core.v3_pool_burn.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v3_pool_burn.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v3_pool_burn.block_timestamp,
  core.v3_pool_burn.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_burn.amount0)
    ELSE ABS(core.v3_pool_burn.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_burn.amount1)
    ELSE ABS(core.v3_pool_burn.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_burn
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v3_pool_burn.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v3_pool_burn.contract) = ANY(LOWER(env(CONCAT(core.v3_pool_burn.chain_id, ':contracts')))::text[])
AND LOWER(core.v3_pool_burn.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v3';

ALTER VIEW liquidity_transaction_view OWNER TO writeuser;

CREATE OR REPLACE VIEW swap_transaction_view
AS
SELECT
  'v2'                                                          AS version,
  core.v2_pair_swap.transaction_sender                          AS account,
  core.v2_pair_swap.chain_id                                    AS chain_id,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v2_pair_swap.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v2_pair_swap.block_timestamp,
  core.v2_pair_swap.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount0_in IS NULL
        THEN core.v2_pair_swap.amount0_out
        WHEN core.v2_pair_swap.amount0_in = 0
        THEN core.v2_pair_swap.amount0_out
        ELSE core.v2_pair_swap.amount0_in
      END
    )
    ELSE ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount1_in IS NULL
        THEN core.v2_pair_swap.amount1_out
        WHEN core.v2_pair_swap.amount1_in = 0
        THEN core.v2_pair_swap.amount1_out
        ELSE core.v2_pair_swap.amount1_in
      END
    )
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount1_in IS NULL
        THEN core.v2_pair_swap.amount1_out
        WHEN core.v2_pair_swap.amount1_in = 0
        THEN core.v2_pair_swap.amount1_out
        ELSE core.v2_pair_swap.amount1_in
      END
    )
    ELSE ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount0_in IS NULL
        THEN core.v2_pair_swap.amount0_out
        WHEN core.v2_pair_swap.amount0_in = 0
        THEN core.v2_pair_swap.amount0_out
        ELSE core.v2_pair_swap.amount0_in
      END
    )
  END                                                           AS token_amount
FROM core.v2_pair_swap
INNER JOIN whitelisted_pool_view
ON  1 = 1
AND core.v2_pair_swap.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v2_pair_swap.contract) = ANY(LOWER(env(CONCAT(core.v2_pair_swap.chain_id, ':contracts')))::text[])
AND LOWER(core.v2_pair_swap.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v2'

UNION ALL

SELECT
  'v3'                                                          AS version,
  core.v3_pool_swap.transaction_sender                          AS account,
  core.v3_pool_swap.chain_id                                    AS chain_id,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v3_pool_swap.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v3_pool_swap.block_timestamp,
  core.v3_pool_swap.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_swap.amount0)
    ELSE ABS(core.v3_pool_swap.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_swap.amount1)
    ELSE ABS(core.v3_pool_swap.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_swap
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v3_pool_swap.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v3_pool_swap.contract) = ANY(LOWER(env(CONCAT(core.v3_pool_swap.chain_id, ':contracts')))::text[])
AND LOWER(core.v3_pool_swap.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v3';

ALTER VIEW swap_transaction_view OWNER TO writeuser;

CREATE OR REPLACE VIEW swap_point_view
AS
WITH swap_transactions
AS
(
  SELECT
    version,
    chain_id,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    stablecoin_amount / POWER(10, env(CONCAT(chain_id, ':', stablecoin, ':decimals'))::numeric) AS amount
  FROM swap_transaction_view
)
SELECT
  version,
  chain_id,
  'swap'                                                                                        AS action,
  account,
  pool_address,
  pool_name,
  block_timestamp,
  transaction_hash,
  amount,
  amount * env('swap:point')::numeric                                                           AS points,
  CASE
    WHEN get_account_by_user_id(get_referrer(account)) IS NULL
    THEN NULL
    ELSE amount * env('swap:point')::numeric * env('referral:points')::numeric
  END                                                                                           AS referral_points,
  get_account_by_user_id(get_referrer(account))                                                 AS referrer
FROM swap_transactions;

ALTER VIEW swap_point_view OWNER TO writeuser;

CREATE OR REPLACE VIEW swap_account_summary_view
AS
SELECT
  account,
  referrer,
  SUM(amount)                   AS amount,
  SUM(points)                   AS points,
  SUM(referral_points)          AS referral_points
FROM swap_point_view
GROUP BY account, referrer;

ALTER VIEW swap_account_summary_view OWNER TO writeuser;

CREATE OR REPLACE VIEW liquidity_point_view
AS
WITH stage1
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    to_timestamp(block_timestamp)                                                                                    AS date,
    (stablecoin_amount * 2) / POWER(10, env(CONCAT(chain_id, ':', stablecoin, ':decimals'))::numeric)                AS amount,
    ROW_NUMBER() OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY to_timestamp(block_timestamp)) AS row_num,
    LEAD
    (
      to_timestamp(block_timestamp),
      1,
      NOW()
    ) OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY to_timestamp(block_timestamp))            AS next_date
  FROM liquidity_transaction_view
),
balances
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    date,
    amount,
    next_date,
    CASE
      WHEN action = 'add'
      THEN amount
      ELSE -amount
    END                                                                                                              AS balance_change
  FROM stage1
),
cumulative
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    date,
    amount,
    next_date,
    SUM(balance_change) OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY date)                   AS balance,
    next_date - date                                                                                                 AS total_duration
  FROM balances
),
daily_points_calculation
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    amount,
    date,
    GREATEST(balance, 0)                                                                                             AS balance,
    EXTRACT(EPOCH FROM total_duration) / 86400                                                                       AS days,
    GREATEST(balance, 0) * env('liquidity:point')::numeric                                                           AS points_per_day
  FROM cumulative
)
SELECT
  version,
  chain_id,
  action,
  account,
  pool_address,
  pool_name,
  block_timestamp,
  transaction_hash,
  amount,
  date,
  balance,
  days,
  points_per_day * days                                                                                              AS points,
  CASE
    WHEN get_account_by_user_id(get_referrer(account)) IS NULL
    THEN NULL
    ELSE points_per_day * days * env('referral:points')::numeric
  END                                                                                                                AS referral_points,
  get_account_by_user_id(get_referrer(account))                                                                      AS referrer
FROM daily_points_calculation;

ALTER VIEW liquidity_point_view OWNER TO writeuser;


CREATE OR REPLACE VIEW liquidity_account_summary_view
AS
SELECT
  account,
  referrer,
  SUM(amount)                   AS amount,
  SUM(points)                   AS points,
  SUM(referral_points)          AS referral_points
FROM liquidity_point_view
GROUP BY account, referrer;

ALTER VIEW liquidity_account_summary_view OWNER TO writeuser;

CREATE OR REPLACE VIEW point_detail_view
AS
SELECT version, chain_id, action, account, pool_name, block_timestamp, transaction_hash, amount, points
FROM swap_point_view
UNION ALL
SELECT version, chain_id, action, account, pool_name, block_timestamp, transaction_hash, amount, points
FROM liquidity_point_view;

ALTER VIEW point_detail_view OWNER TO writeuser;

CREATE OR REPLACE VIEW point_view
AS
WITH combined
AS
(
  SELECT account, points FROM liquidity_point_view
  UNION ALL
  SELECT account, points FROM swap_point_view
),
consolidated
AS
(
  SELECT
    account,
    get_name_by_account(account)  AS moniker,
    SUM(points)                   AS points
  FROM combined
  GROUP BY account
),
ranked
AS
(
  SELECT
    DENSE_RANK() OVER(ORDER BY points DESC, account ASC) AS rank,
    moniker,
    account,
    points::numeric(20, 2)
  FROM consolidated
  ORDER BY points DESC
)
SELECT * FROM ranked;

ALTER VIEW point_view OWNER TO writeuser;

CREATE OR REPLACE VIEW point_summary_view
AS
WITH summary
AS
(
  SELECT
    SUM(points) AS total,
    COUNT(account) AS starfinders
  FROM point_view
),
top_accounts
AS
(
  SELECT * 
  FROM point_view
  ORDER BY rank ASC
  LIMIT 3
)
SELECT * FROM top_accounts
CROSS JOIN summary;

ALTER VIEW point_summary_view OWNER TO writeuser;

CREATE SCHEMA IF NOT EXISTS meta;

CREATE TABLE IF NOT EXISTS meta.locks
(
  id                                                BIGSERIAL PRIMARY KEY NOT NULL,
  project_id                                        text,
  created_at                                        TIMESTAMP WITH TIME ZONE DEFAULT (NOW())
);

CREATE UNIQUE INDEX IF NOT EXISTS locks_project_id_uix
ON meta.locks (LOWER(project_id));

-- SELECT * FROM meta.locks;

--
CREATE OR REPLACE FUNCTION get_explorer_home
(
  _sort_by                                                              text,
  _sort_direction                                                       text,
  _page_number                                                          integer,
  _page_size                                                            integer,
  _date_from                                                            TIMESTAMP WITH TIME ZONE,
  _date_to                                                              TIMESTAMP WITH TIME ZONE,
  _networks                                                             numeric[],
  _contracts                                                            text[],
  _event_name_like                                                      text,
  _transaction_sender_like                                              text,
  _transaction_hash_like                                                text,
  _block_number_like                                                    text
)
RETURNS TABLE
(
  id                                                                    uuid,
  chain_id                                                              uint256,
  date                                                                  TIMESTAMP WITH TIME ZONE,
  event_name                                                            text,
  transaction_sender                                                    address,
  contract                                                              address,
  transaction_hash                                                      text,
  block_number                                                          text,
  page_size                                                             integer,
  page_number                                                           integer,
  total_records                                                         integer,
  total_pages                                                           integer
)
STABLE
AS
$$
  DECLARE _total_records                                                integer;
  DECLARE _total_pages                                                  integer;
  DECLARE _query                                                        text;
BEGIN
  IF(COALESCE(_sort_direction, '') = '') THEN
    _sort_direction := 'ASC';
  END IF;
  
  IF(_sort_direction NOT IN ('ASC', 'DESC')) THEN
    RAISE EXCEPTION 'Access is denied. Invalid sort_direction: "%"', _sort_direction; --SQL Injection Attack
  END IF;

  IF(_networks IS NULL) THEN
    _networks := array_agg(DISTINCT core.transactions.chain_id) FROM core.transactions;
  END IF;

  IF(_contracts IS NULL) THEN
    _contracts := array_agg(DISTINCT core.transactions.address) FROM core.transactions;  
  END IF;

  IF(_sort_by NOT IN('chain_id', 'date', 'event_name', 'transaction_sender', 'contract', 'block_number', 'transaction_hash')) THEN
    RAISE EXCEPTION 'Access is denied. Invalid sort_by: "%"', _sort_by; --SQL Injection Attack
  END IF;
  
  IF(_sort_by = 'date') THEN
    _sort_by := 'block_timestamp';
  END IF;
      
  IF(_page_number < 1) THEN
    RAISE EXCEPTION 'Invalid page_number value %', _page_number;  
  END IF;
  
  IF(_page_size < 1) THEN
    RAISE EXCEPTION 'Invalid _page_size value %', _page_size;  
  END IF;
  
  
  _query := format('
  WITH result AS
  (
    SELECT * FROM core.transactions
    WHERE core.transactions.block_timestamp
    BETWEEN
      EXTRACT(epoch FROM COALESCE(%L, ''-infinity''::date))
      AND EXTRACT(epoch FROM COALESCE(%L, ''infinity''::date))  
    AND core.transactions.chain_id                                      = ANY(%L)
    AND core.transactions.address                                       = ANY(%L)
    AND core.transactions.event_name                                    ILIKE %s
    AND core.transactions.transaction_sender                            ILIKE %s
    AND core.transactions.transaction_hash                              ILIKE %s
    AND core.transactions.block_number                                  ILIKE %s
  )
  SELECT COUNT(*) FROM result;', _date_from, _date_to, _networks, _contracts, quote_literal_ilike(_event_name_like), quote_literal_ilike(_transaction_sender_like), quote_literal_ilike(_transaction_hash_like), quote_literal_ilike(_block_number_like));
  
  EXECUTE _query
  INTO _total_records;
  
  _total_pages = COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  
  _query := format('
  SELECT
    core.transactions.id,
    core.transactions.chain_id,
    to_timestamp(core.transactions.block_timestamp)::TIMESTAMP WITH TIME ZONE AS date,
    core.transactions.event_name,
    core.transactions.transaction_sender,
    core.transactions.address,
    core.transactions.transaction_hash,
    core.transactions.block_number,
    %s                                                                  AS page_size,
    %s                                                                  AS page_number,
    %s                                                                  AS total_records,
    %s                                                                  AS total_pages
  FROM core.transactions
  WHERE core.transactions.block_timestamp
  BETWEEN 
    EXTRACT(epoch FROM COALESCE(%L, ''-infinity''::date))
    AND EXTRACT(epoch FROM COALESCE(%L, ''infinity''::date))
  AND core.transactions.chain_id                                        = ANY(%L)
  AND core.transactions.address                                         = ANY(%L)
  AND core.transactions.event_name                                      ILIKE %s
  AND core.transactions.transaction_sender                              ILIKE %s
  AND core.transactions.transaction_hash                                ILIKE %s
  AND core.transactions.block_number                                    ILIKE %s
  ORDER BY %I %s
  LIMIT %s::integer
  OFFSET %s::integer * %s::integer  
  ', _page_size, _page_number, _total_records, _total_pages, _date_from, _date_to, _networks, _contracts, quote_literal_ilike(_event_name_like), quote_literal_ilike(_transaction_sender_like), quote_literal_ilike(_transaction_hash_like), quote_literal_ilike(_block_number_like), _sort_by, _sort_direction, _page_size, _page_number - 1, _page_size);

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_explorer_home OWNER TO writeuser;

-- SELECT * FROM get_explorer_home
-- (
--   'date',           --_sort_by                                       text,
--   'DESC',           --_sort_direction                                text,
--   1,                --_page_number                                   integer,
--   2,                --_page_size                                     integer,
--   NULL,             --_date_from                                     TIMESTAMP WITH TIME ZONE,
--   '1-1-2099'::date, --_date_to                                       TIMESTAMP WITH TIME ZONE,
--   NULL,             --_networks                                      numeric[],
--   NULL,             --_contracts                                     text[],
--   '',               --_event_name_like                               text,
--   '',               --_transaction_sender_like                       text
--   '',               --_transaction_hash_like                         text
--   ''                --_block_number_like                             text
-- );

CREATE OR REPLACE FUNCTION get_explorer_stats()
RETURNS TABLE
(
  transaction_count                                   integer,
  total_swaps                                         numeric,
  liquidity_added                                     numeric,
  liquidity_removed                                   numeric,
  average_gas_price                                   numeric,
  average_gas_price_today                             numeric
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_explorer_stats_result;
  CREATE TEMPORARY TABLE _get_explorer_stats_result
  (
    transaction_count                                 integer,
    total_swaps                                       numeric,
    liquidity_added                                   numeric,
    liquidity_removed                                 numeric,
    average_gas_price                                 numeric,
    average_gas_price_today                           numeric
  ) ON COMMIT DROP;
  
  INSERT INTO _get_explorer_stats_result(transaction_count)
  SELECT COUNT(DISTINCT transaction_hash)
  FROM core.transactions;
  
  WITH
  v2_result
  AS
  (
    SELECT count(*) as total_count 
    FROM core.v2_pair_swap
  ),
  v3_result
  AS
  (
    SELECT count(*) as total_count
    FROM core.v3_pool_swap
  )
  UPDATE _get_explorer_stats_result
  SET total_swaps = 
  (
    SELECT v2_result.total_count + v3_result.total_count
    FROM v2_result, v3_result
  );

  WITH
  v2_result
  AS
  (
    SELECT count(*) as total_count 
    FROM core.v2_pair_mint
  ),
  v3_result
  AS
  (
    SELECT count(*) as total_count
    FROM core.v3_pool_mint
  )
  UPDATE _get_explorer_stats_result
  SET liquidity_added = 
  (
    SELECT v2_result.total_count + v3_result.total_count
    FROM v2_result, v3_result
  );
  
  WITH
  v2_result
  AS
  (
    SELECT count(*) as total_count 
    FROM core.v2_pair_burn
  ),
  v3_result
  AS
  (
    SELECT count(*) as total_count
    FROM core.v3_pool_burn
  )
  UPDATE _get_explorer_stats_result
  SET liquidity_removed = 
  (
    SELECT v2_result.total_count + v3_result.total_count
    FROM v2_result, v3_result
  );

  UPDATE _get_explorer_stats_result
  SET average_gas_price = COALESCE
    (
      (
        SELECT AVG(core.transactions.gas_price)
        FROM core.transactions
        WHERE block_timestamp 
        BETWEEN 
          CEILING(EXTRACT(EPOCH FROM NOW() - INTERVAL '2 days')) 
          AND CEILING(EXTRACT(EPOCH FROM NOW() - INTERVAL '1 day'))
      ), 
    0
    );

  UPDATE _get_explorer_stats_result
  SET average_gas_price_today = COALESCE
    (
      (
        SELECT AVG(core.transactions.gas_price)
        FROM core.transactions
        WHERE block_timestamp > CEILING(EXTRACT(EPOCH FROM NOW() - INTERVAL '1 day'))
      ), 
    0
    );
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_explorer_stats OWNER TO writeuser;
--

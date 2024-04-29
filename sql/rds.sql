CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP SCHEMA IF EXISTS core CASCADE;
CREATE SCHEMA core;

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


CREATE TABLE core.locks
(
  namespace                                         text NOT NULL PRIMARY KEY,
  started_on                                        integer NOT NULL DEFAULT(extract(epoch FROM NOW() AT TIME ZONE 'UTC'))
);

CREATE TABLE core.transactions
(
  id                                                uuid PRIMARY KEY DEFAULT(gen_random_uuid()),
  transaction_hash                                  text NOT NULL,
  address                                           address /* NOT NULL */,
  block_timestamp                                   integer NOT NULL,
  log_index                                         integer NOT NULL,
  block_number                                      text NOT NULL,
  transaction_sender                                address,
  chain_id                                          uint256 NOT NULL,
  gas_price                                         uint256,
  event_name                                        text
);

CREATE INDEX IF NOT EXISTS transactions_transaction_hash_inx
ON core.transactions(transaction_hash);

CREATE INDEX IF NOT EXISTS transactions_address_inx
ON core.transactions(address);

CREATE INDEX IF NOT EXISTS transactions_block_timestamp_inx
ON core.transactions(block_timestamp);

CREATE INDEX IF NOT EXISTS transactions_log_index_inx
ON core.transactions(log_index);

CREATE INDEX IF NOT EXISTS transactions_block_number_inx
ON core.transactions(block_number);

CREATE INDEX IF NOT EXISTS transactions_chain_id_inx
ON core.transactions(chain_id);

CREATE INDEX IF NOT EXISTS transactions_event_name_inx
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
  position                                        uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v2_factory_pair_created_token0_inx
ON core.v2_factory_pair_created(token0);

CREATE INDEX IF NOT EXISTS v2_factory_pair_created_token1_inx
ON core.v2_factory_pair_created(token1);

/***************************************************************************************
UniswapV2Pair.json
event Approval(address indexed owner, address indexed spender, uint256 value)
***************************************************************************************/
CREATE TABLE core.v2_pair_approval
(
  owner                                           address NOT NULL,
  spender                                         address NOT NULL,
  value                                           uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v2_pair_approval_owner_inx
ON core.v2_pair_approval(owner);

CREATE INDEX IF NOT EXISTS v2_pair_approval_spender_inx
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
  sent_to                                         address NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v2_pair_burn_sender_inx
ON core.v2_pair_burn(sender);

CREATE INDEX IF NOT EXISTS v2_pair_burn_sent_to_inx
ON core.v2_pair_burn(sent_to);

/***************************************************************************************
UniswapV2Pair.json
event Mint(address indexed sender, uint256 amount0, uint256 amount1)
***************************************************************************************/

CREATE TABLE core.v2_pair_mint
(
  sender                                          address NOT NULL,
  amount0                                         uint256 NOT NULL,
  amount1                                         uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v2_pair_mint_sender_inx
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
  sent_to                                         address NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v2_pair_swap_sender_inx
ON core.v2_pair_swap(sender);

CREATE INDEX IF NOT EXISTS v2_pair_swap_sent_to_inx
ON core.v2_pair_swap(sent_to);

/***************************************************************************************
UniswapV2Pair.json
event Sync(uint112 reserve0, uint112 reserve1)
***************************************************************************************/

CREATE TABLE core.v2_pair_sync
(
  reserve0                                        uint112 NOT NULL,
  reserve1                                        uint112 NOT NULL
) INHERITS (core.transactions);

/***************************************************************************************
UniswapV2Pair.json
event Transfer(address indexed sender, address indexed receiver, uint256 value)
***************************************************************************************/

CREATE TABLE core.v2_pair_transfer
(
  sender                                          address NOT NULL,
  receiver                                        address NOT NULL,
  value                                           uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v2_pair_transfer_sender_inx
ON core.v2_pair_transfer(sender);

CREATE INDEX IF NOT EXISTS v2_pair_transfer_receiver_inx
ON core.v2_pair_transfer(receiver);

/***************************************************************************************
UniswapV3Factory.json
event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing)
***************************************************************************************/

CREATE TABLE core.v3_factory_fee_amount_enabled
(
  fee                                             uint24 NOT NULL,
  tick_spacing                                    int24 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_factory_fee_amount_enabled_fee_inx
ON core.v3_factory_fee_amount_enabled(fee);

CREATE INDEX IF NOT EXISTS v3_factory_fee_amount_enabled_tick_spacing_inx
ON core.v3_factory_fee_amount_enabled(tick_spacing);

/***************************************************************************************
UniswapV3Factory.json
event OwnerChanged(address indexed oldOwner, address indexed newOwner)
***************************************************************************************/

CREATE TABLE core.owner_changed
(
  old_owner                                       address NOT NULL,
  new_owner                                       address NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS owner_changed_old_owner_inx
ON core.owner_changed(old_owner);

CREATE INDEX IF NOT EXISTS owner_changed_new_owner_inx
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
  pool                                            address NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_factory_pool_created_token0_inx
ON core.v3_factory_pool_created(token0);

CREATE INDEX IF NOT EXISTS v3_factory_pool_created_token1_inx
ON core.v3_factory_pool_created(token1);

CREATE INDEX IF NOT EXISTS v3_factory_pool_created_pool_inx
ON core.v3_factory_pool_created(pool);

/***************************************************************************************
NonfungibleTokenPositionDescriptor.json
event UpdateTokenRatioPriority(address token, int256 priority)
***************************************************************************************/

CREATE TABLE core.update_token_ratio_priority
(
  token                                           address NOT NULL,
  priority                                        int256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS update_token_ratio_priority_token_inx
ON core.update_token_ratio_priority(token);

/***************************************************************************************
NonfungiblePositionManager.json
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_approval
(
  owner                                           address NOT NULL,
  approved                                        address NOT NULL,
  token_id                                        uint256 NOT NULL
) INHERITS (core.transactions);


CREATE INDEX IF NOT EXISTS nft_position_manager_approval_owner_inx
ON core.nft_position_manager_approval(owner);

CREATE INDEX IF NOT EXISTS nft_position_manager_approval_approved_inx
ON core.nft_position_manager_approval(approved);

CREATE INDEX IF NOT EXISTS nft_position_manager_approval_token_id_inx
ON core.nft_position_manager_approval(token_id);

/***************************************************************************************
NonfungiblePositionManager.json
event ApprovalForAll(address indexed owner, address indexed operator, bool approved)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_approval_for_all
(
  owner                                           address NOT NULL,
  operator                                        address NOT NULL,
  approved                                        boolean NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS nft_position_manager_approval_for_all_owner_inx
ON core.nft_position_manager_approval_for_all(owner);

CREATE INDEX IF NOT EXISTS nft_position_manager_approval_for_all_operator_inx
ON core.nft_position_manager_approval_for_all(operator);

CREATE INDEX IF NOT EXISTS nft_position_manager_approval_for_all_approved_inx
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
  amount1                                         uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS nft_position_manager_collect_token_id_inx
ON core.nft_position_manager_collect(token_id);

CREATE INDEX IF NOT EXISTS nft_position_manager_collect_recipient_inx
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
  amount1                                         uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS nft_position_manager_decrease_liquidity_token_id_inx
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
  amount1                                         uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS nft_position_manager_increase_liquidity_token_id_inx
ON core.nft_position_manager_increase_liquidity(token_id);

/***************************************************************************************
NonfungiblePositionManager.json
event Transfer(address indexed sender, address indexed receiver, uint256 indexed tokenId)
***************************************************************************************/

CREATE TABLE core.nft_position_manager_transfer
(
  sender                                          address NOT NULL,
  receiver                                        address NOT NULL,
  token_id                                        uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS nft_position_manager_transfer_sender_inx
ON core.nft_position_manager_transfer(sender);

CREATE INDEX IF NOT EXISTS nft_position_manager_transfer_receiver_inx
ON core.nft_position_manager_transfer(receiver);

CREATE INDEX IF NOT EXISTS nft_position_manager_transfer_token_id_inx
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
  expiration                                      uint48 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS permit2_approval_owner_inx
ON core.permit2_approval(owner);

CREATE INDEX IF NOT EXISTS permit2_approval_token_inx
ON core.permit2_approval(token);

CREATE INDEX IF NOT EXISTS permit2_approval_spender_inx
ON core.permit2_approval(spender);

/***************************************************************************************
Permit2.json
event Lockdown(address indexed owner, address token, address spender)
***************************************************************************************/

CREATE TABLE core.permit2_lockdown
(
  owner                                           address NOT NULL,
  token                                           address NOT NULL,
  spender                                         address NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS permit2_lockdown_owner_inx
ON core.permit2_lockdown(owner);

CREATE INDEX IF NOT EXISTS permit2_lockdown_token_inx
ON core.permit2_lockdown(token);

CREATE INDEX IF NOT EXISTS permit2_lockdown_spender_inx
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
  old_nonce                                       uint48 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS permit2_nonce_invalidation_owner_inx
ON core.permit2_nonce_invalidation(owner);

CREATE INDEX IF NOT EXISTS permit2_nonce_invalidation_token_inx
ON core.permit2_nonce_invalidation(token);

CREATE INDEX IF NOT EXISTS permit2_nonce_invalidation_spender_inx
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
  nonce                                           uint48 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS permit2_owner_inx
ON core.permit(owner);

CREATE INDEX IF NOT EXISTS permit2_token_inx
ON core.permit(token);

CREATE INDEX IF NOT EXISTS permit2_spender_inx
ON core.permit(spender);

/***************************************************************************************
Permit2.json
event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask)
***************************************************************************************/

CREATE TABLE core.permit2_unordered_nonce_invalidation
(
  owner                                           address NOT NULL,
  word                                            uint256 NOT NULL,
  mask                                            uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS permit2_unordered_nonce_invalidation_owner_inx
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
  amount1                                         uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_burn_owner_inx
ON core.v3_pool_burn(owner);

CREATE INDEX IF NOT EXISTS v3_pool_burn_tick_lower_inx
ON core.v3_pool_burn(tick_lower);

CREATE INDEX IF NOT EXISTS v3_pool_burn_tick_upper_inx
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
  amount1                                         uint128 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_collect_owner_inx
ON core.v3_pool_collect(owner);

CREATE INDEX IF NOT EXISTS v3_pool_collect_recipient_inx
ON core.v3_pool_collect(recipient);

CREATE INDEX IF NOT EXISTS v3_pool_collect_tick_lower_inx
ON core.v3_pool_collect(tick_lower);

CREATE INDEX IF NOT EXISTS v3_pool_collect_tick_upper_inx
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
  amount1                                         uint128 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_collect_protocol_sender_inx
ON core.v3_pool_collect_protocol(sender);

CREATE INDEX IF NOT EXISTS v3_pool_collect_protocol_recipient_inx
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
  paid1                                           uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_flash_sender_inx
ON core.v3_pool_flash(sender);

CREATE INDEX IF NOT EXISTS v3_pool_flash_recipient_inx
ON core.v3_pool_flash(recipient);

/***************************************************************************************
UniswapV3Pool.json
event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, 
                                         uint16 observationCardinalityNextNew)
***************************************************************************************/

CREATE TABLE core.v3_pool_increase_observation_cardinality_next
(
  observation_cardinality_next_old                uint16 NOT NULL,
  observation_cardinality_next_new                uint16 NOT NULL
) INHERITS (core.transactions);


/***************************************************************************************
UniswapV3Pool.json
event Initialize(uint160 sqrtPriceX96, int24 tick)
***************************************************************************************/

CREATE TABLE core.v3_pool_initialize
(
  sqrt_price_x96                                  uint160 NOT NULL,
  tick                                            int24 NOT NULL
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
  amount1                                         uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_mint_sender_inx
ON core.v3_pool_mint(sender);

CREATE INDEX IF NOT EXISTS v3_pool_mint_owner_inx
ON core.v3_pool_mint(owner);

CREATE INDEX IF NOT EXISTS v3_pool_mint_tick_lower_inx
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
  fee_protocol1_new                               uint8 NOT NULL
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
  tick                                            int24 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_swap_sender_inx
ON core.v3_pool_swap(sender);

CREATE INDEX IF NOT EXISTS v3_pool_swap_recipient_inx
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
  new_owner                                       address NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS deposit_transferred_token_id_inx
ON core.deposit_transferred(token_id);

CREATE INDEX IF NOT EXISTS deposit_transferred_old_owner_inx
ON core.deposit_transferred(old_owner);

CREATE INDEX IF NOT EXISTS deposit_transferred_new_owner_inx
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
  reward                                          uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_incentive_created_reward_token_inx
ON core.v3_pool_incentive_created(reward_token);

CREATE INDEX IF NOT EXISTS v3_pool_incentive_created_pool_inx
ON core.v3_pool_incentive_created(pool);

/***************************************************************************************
UniswapV3Pool.json
event IncentiveEnded(bytes32 indexed incentiveId, uint256 refund)
***************************************************************************************/

CREATE TABLE core.v3_pool_incentive_ended
(
  incentive_id                                    bytes32 NOT NULL,
  refund                                          uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_incentive_ended_incentive_id_inx
ON core.v3_pool_incentive_ended(incentive_id);

/***************************************************************************************
UniswapV3Pool.json
event RewardClaimed(address indexed sentTo, uint256 reward)
***************************************************************************************/

CREATE TABLE core.v3_pool_reward_claimed
(
  sent_to                                         address NOT NULL,
  reward                                          uint256 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_reward_claimed_sent_to_inx
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
  liquidity                                       uint128 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_token_staked_token_id_inx
ON core.v3_pool_token_staked(token_id);

CREATE INDEX IF NOT EXISTS v3_pool_token_staked_incentive_id_inx
ON core.v3_pool_token_staked(incentive_id);

/***************************************************************************************
UniswapV3Pool.json
event TokenUnstaked(uint256 indexed tokenId, bytes32 indexed incentiveId)
***************************************************************************************/

CREATE TABLE core.v3_pool_token_unstaked
(
  token_id                                        uint256 NOT NULL,
  incentive_id                                    bytes32 NOT NULL
) INHERITS (core.transactions);

CREATE INDEX IF NOT EXISTS v3_pool_token_unstaked_token_id_inx
ON core.v3_pool_token_unstaked(token_id);

CREATE INDEX IF NOT EXISTS v3_pool_token_unstaked_incentive_id_inx
ON core.v3_pool_token_unstaked(incentive_id);

/***************************************************************************************
UniversalRouter.json
event RewardsSent(uint256 amount)
***************************************************************************************/

CREATE TABLE core.universal_router_rewards_sent
(
  amount                                          uint256 NOT NULL
) INHERITS (core.transactions);



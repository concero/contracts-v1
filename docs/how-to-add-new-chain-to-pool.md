## How to add new chain to pools infrastructure

### Step 1: Deploy child pool contracts on the chain

### Step 2: Add new child pool proxy contract to each child pools
#### Call ```function setPools(uint64 _chainSelector, address _pool) external payable onlyOwner```

### Step 3: Add new child pool proxy to the parent pool
#### Call ```function setPools(uint64 _chainSelector, address _pool, bool isRebalancingNeeded) external``` with isRebalancingNeeded = true
#### After rebalancing is done add new chain to all parent pool clf js code chains maps
